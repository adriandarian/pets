import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetUpdateIntegrationSourceTests {
    @Test
    func appChecksGitHubAndOffersManualReleaseDownload() throws {
        let controller = try source("Sources/Pets/PetUpdateController.swift")
        let app = try source("Sources/Pets/PetsApp.swift")
        let settings = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(controller.contains("api.github.com/repos/adriandarian/pets/releases/latest"))
        #expect(controller.contains("PetsReleaseParser.newerRelease"))
        #expect(controller.contains("NSWorkspace.shared.open"))
        #expect(app.contains("updateController.start()"))
        #expect(app.contains("Check for Updates"))
        #expect(settings.contains("PetUpdateBanner"))
        #expect(settings.contains("View on GitHub"))
    }

    @Test
    func packagingKeepsThePermanentBundleIdentifierAndUsesVersionFiles() throws {
        let runScript = try source("scripts/run_app.sh")
        let releaseScript = try source("scripts/build_release.sh")
        let publishScript = try source("scripts/publish_release.sh")
        let version = try source("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
        let build = try source("BUILD_NUMBER").trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(runScript.contains("BUNDLE_ID=\"local.pets.Pets\""))
        #expect(runScript.contains("VERSION_FILE=\"VERSION\""))
        #expect(releaseScript.contains("swift build -c release"))
        #expect(releaseScript.contains("ARCHIVE_PATH=\"dist/${APP_NAME}-${VERSION}.zip\""))
        #expect(publishScript.contains("gh release create"))
        #expect(publishScript.contains("--generate-notes"))
        #expect(PetsVersion(version) != nil)
        #expect(Int(build) != nil)
    }

    @Test
    func persistenceKeepsRawBackupsBeforeFutureMigrations() throws {
        let settings = try source("Sources/Pets/PetSettingsPersistence.swift")
        let collection = try source("Sources/Pets/PetCollectionPersistence.swift")

        #expect(settings.contains("petInstancesBackup"))
        #expect(settings.contains("backupPetInstancesIfNeeded"))
        #expect(collection.contains("collectionStateBackup"))
        #expect(collection.contains("backupCollectionStateIfNeeded"))
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
