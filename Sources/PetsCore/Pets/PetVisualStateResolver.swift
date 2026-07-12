public struct PetVisualContext: Equatable, Sendable {
    public let status: HarnessSessionStatus
    public let hasActiveSessions: Bool
    public let isHovered: Bool
    public let animationSettings: PetAnimationSettings
    public let reaction: PetReaction?
    public let animationPhaseOffset: Double

    public init(
        status: HarnessSessionStatus,
        hasActiveSessions: Bool,
        isHovered: Bool,
        animationSettings: PetAnimationSettings,
        reaction: PetReaction? = nil,
        animationPhaseOffset: Double = 0
    ) {
        self.status = status
        self.hasActiveSessions = hasActiveSessions
        self.isHovered = isHovered
        self.animationSettings = animationSettings
        self.reaction = reaction
        self.animationPhaseOffset = min(0.999_999, max(0, animationPhaseOffset))
    }
}

public enum PetVisualStateResolver {
    public static func requestedState(for context: PetVisualContext) -> PetVisualState {
        switch context.reaction {
        case .some(.completion):
            return .completion
        case .some(.error):
            return .error
        case nil:
            break
        }

        if context.isHovered && context.animationSettings.isHoverBounceEnabled {
            return .excited
        }
        guard context.animationSettings.areStatusMoodsEnabled else { return .idle }
        guard context.hasActiveSessions else { return .sleeping }

        switch context.status {
        case .waiting:
            return .waiting
        case .busy:
            return .busy
        case .idle, .unknown:
            return .idle
        }
    }
}
