public struct PetVisualContext: Equatable, Sendable {
    public let status: HarnessSessionStatus
    public let hasActiveSessions: Bool
    public let isHovered: Bool
    public let animationSettings: PetAnimationSettings

    public init(
        status: HarnessSessionStatus,
        hasActiveSessions: Bool,
        isHovered: Bool,
        animationSettings: PetAnimationSettings
    ) {
        self.status = status
        self.hasActiveSessions = hasActiveSessions
        self.isHovered = isHovered
        self.animationSettings = animationSettings
    }
}

public enum PetVisualStateResolver {
    public static func requestedState(for context: PetVisualContext) -> PetVisualState {
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
