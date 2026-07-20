import Foundation

public enum PetTrackingProvider: String, CaseIterable, Codable, Hashable, Sendable {
    case claudeCode = "claude"
    case codex
    case githubCopilot = "copilot"

    public var displayName: String {
        switch self {
        case .claudeCode:
            "Claude Code"
        case .codex:
            "Codex"
        case .githubCopilot:
            "GitHub Copilot"
        }
    }

    public var sessionDescription: String {
        switch self {
        case .claudeCode:
            "Claude Code chats"
        case .codex:
            "App and CLI tasks"
        case .githubCopilot:
            "CLI and chat sessions"
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
