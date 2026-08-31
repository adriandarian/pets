import Foundation

public enum PetTrackingProvider: String, CaseIterable, Codable, Hashable, Sendable {
    case claudeCode = "claude"
    case codex
    case githubCopilot = "copilot"
    case cursor
    case ollama
    case gemini
    case antigravity
    case hermes
    case t3Code = "t3code"
    case openDesign = "open-design"
    case kiro
    case zed
    case windsurf
    case openCode = "opencode"
    case pi
    case notebookLM = "notebooklm"
    case lmStudio = "lm-studio"
    case stitch

    public var displayName: String {
        switch self {
        case .claudeCode:
            "Claude Code"
        case .codex:
            "Codex"
        case .githubCopilot:
            "GitHub Copilot"
        case .cursor:
            "Cursor"
        case .ollama:
            "Ollama"
        case .gemini:
            "Gemini"
        case .antigravity:
            "Antigravity"
        case .hermes:
            "Hermes"
        case .t3Code:
            "T3 Code"
        case .openDesign:
            "Open Design"
        case .kiro:
            "Kiro"
        case .zed:
            "Zed"
        case .windsurf:
            "Windsurf"
        case .openCode:
            "opencode"
        case .pi:
            "pi"
        case .notebookLM:
            "NotebookLM"
        case .lmStudio:
            "LM Studio"
        case .stitch:
            "Stitch"
        }
    }

    public var systemImageName: String {
        switch self {
        case .claudeCode:
            "sparkles"
        case .codex:
            "terminal"
        case .githubCopilot:
            "chevron.left.forwardslash.chevron.right"
        case .cursor:
            "cursorarrow.rays"
        case .ollama:
            "brain.head.profile"
        case .gemini:
            "sparkles.rectangle.stack"
        case .antigravity:
            "arrow.up.circle"
        case .hermes:
            "paperplane"
        case .t3Code, .openCode:
            "chevron.left.forwardslash.chevron.right"
        case .openDesign:
            "paintbrush.pointed"
        case .kiro:
            "shippingbox"
        case .zed:
            "bolt"
        case .windsurf:
            "wind"
        case .pi:
            "apple.terminal"
        case .notebookLM:
            "book.pages"
        case .lmStudio:
            "cpu"
        case .stitch:
            "rectangle.3.group"
        }
    }
}

public enum PetTrackerAssignments {
    public static func normalized(_ instances: [PetInstance]) -> [PetInstance] {
        var claimedProviders: Set<PetTrackingProvider> = []

        return instances.map { instance in
            var normalized = instance
            normalized.trackingProviders = normalized.trackingProviders.filter { provider in
                claimedProviders.insert(provider).inserted
            }
            return normalized
        }
    }

    public static func setting(
        _ provider: PetTrackingProvider,
        isEnabled: Bool,
        for petID: PetInstance.ID,
        in instances: [PetInstance]
    ) -> [PetInstance] {
        guard let targetIndex = instances.firstIndex(where: { $0.id == petID }) else {
            return instances
        }
        if isEnabled,
           instances.contains(where: {
               $0.id != petID && $0.trackingProviders.contains(provider)
           }) {
            return instances
        }

        var updated = instances
        if isEnabled {
            updated[targetIndex].trackingProviders.insert(provider)
        } else {
            updated[targetIndex].trackingProviders.remove(provider)
        }
        return updated
    }
}
