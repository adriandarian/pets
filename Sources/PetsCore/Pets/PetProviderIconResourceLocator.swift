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
        resourceBundle.url(
            forResource: resourceName(for: provider, appearance: appearance),
            withExtension: "png",
            subdirectory: "ProviderIcons"
        )
    }

    private static func resourceName(
        for provider: PetTrackingProvider,
        appearance: PetProviderIconAppearance
    ) -> String {
        switch provider {
        case .claudeCode:
            "claude"
        case .codex:
            appearance == .dark ? "codex-dark" : "codex-light"
        case .githubCopilot:
            appearance == .dark ? "github-dark" : "github-light"
        }
    }
}
