import Foundation
import Testing

@Suite
struct PetDevelopmentPlatformSourceTests {
    @Test
    func developmentAppUsesAnExplicitCompilationFlagAndIsolatedPreferences() throws {
        let script = try source("scripts/run_dev_app.sh")
        let launcher = try source("scripts/run_app.sh")

        #expect(script.contains("-DPETS_DEVELOPMENT"))
        #expect(script.contains("APP_NAME=\"Pets Dev\""))
        #expect(script.contains("BUNDLE_ID=\"local.pets.Pets.dev\""))
        #expect(launcher.contains("\"${1:-}\" == \"--dev\""))
        #expect(!launcher.contains("--unlimited-keys"))
        #expect(!launcher.contains("--development"))
    }

    @Test
    func releaseBuildDoesNotCompileOrPackageDevelopmentMode() throws {
        let releaseScript = try source("scripts/build_release.sh")
        let store = try source("Sources/Pets/PetStore.swift")
        let collectionView = try source("Sources/Pets/PetCollectionViews.swift")
        let app = try source("Sources/Pets/PetsApp.swift")

        #expect(!releaseScript.contains("PETS_DEVELOPMENT"))
        #expect(store.contains("#if PETS_DEVELOPMENT"))
        #expect(collectionView.contains("#if PETS_DEVELOPMENT"))
        #expect(collectionView.contains("PetDevelopmentControls"))
        #expect(app.contains("Label(\"Pets Dev\", systemImage: \"hammer.circle\")"))
    }

    @Test
    func developmentCollectionSupportsUnlimitedKeysResetAndUnlockAll() throws {
        let store = try source("Sources/Pets/PetStore.swift")
        let collectionView = try source("Sources/Pets/PetCollectionViews.swift")

        #expect(store.contains("PetKeyInventory(rarity: rarity, count: 1)"))
        #expect(store.contains("func resetCollectedPetsForDevelopment()"))
        #expect(store.contains("func unlockAllPetsForDevelopment()"))
        #expect(collectionView.contains("Unlimited \\(rarity.displayName) Keys"))
        #expect(collectionView.contains("Button(\"Unlock All Pets\")"))
        #expect(collectionView.contains("Button(\"Reset Collected Pets\", role: .destructive)"))
    }

    private func source(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/" {
            if FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path) {
                return try String(contentsOf: root.appending(path: path), encoding: .utf8)
            }
            root.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
