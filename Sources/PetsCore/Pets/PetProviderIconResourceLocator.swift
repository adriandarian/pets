import Foundation

public enum PetProviderIconAppearance: CaseIterable, Sendable {
    case light
    case dark
}

public enum PetProviderIconResourceLocator {
    private static let resourceBundle: Bundle = {
        let packagedBundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("Pets_PetsCore.bundle", isDirectory: true)

        if let packagedBundleURL,
           let packagedBundle = Bundle(url: packagedBundleURL) {
            return packagedBundle
        }

        return Bundle.module
    }()

    public static func url(
        for provider: PetTrackingProvider,
        appearance: PetProviderIconAppearance
    ) -> URL? {
        guard let resourceName = resourceName(for: provider, appearance: appearance) else {
            return nil
        }
        return resourceBundle.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: "ProviderIcons"
        )
    }

    private static func resourceName(
        for provider: PetTrackingProvider,
        appearance: PetProviderIconAppearance
    ) -> String? {
        switch provider {
        case .claudeCode:
            "claude"
        case .codex:
            appearance == .dark ? "codex-dark" : "codex-light"
        case .githubCopilot:
            appearance == .dark ? "github-dark" : "github-light"
        case .cursor:
            "cursor"
        case .ollama:
            "ollama"
        case .gemini:
            "gemini"
        case .antigravity:
            "antigravity"
        case .hermes:
            "hermes"
        case .t3Code:
            "t3code"
        case .openDesign:
            "open-design"
        case .kiro:
            "kiro"
        case .zed:
            "zed"
        case .windsurf:
            "windsurf"
        case .openCode:
            "opencode"
        case .pi:
            appearance == .dark ? "pi-dark" : "pi-light"
        case .notebookLM:
            "notebooklm"
        case .lmStudio:
            "lm-studio"
        case .stitch:
            "stitch"
        }
    }
}
