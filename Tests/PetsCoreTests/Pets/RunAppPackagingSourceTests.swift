import Foundation
import Testing

@Suite
struct RunAppPackagingSourceTests {
    @Test
    func packagedAppsCarryResourcesInTheStandardLocationAndSealTheBundle() throws {
        let root = try repositoryRoot()

        for scriptPath in [
            "scripts/run_app.sh",
            "scripts/run_dev_app.sh",
        ] {
            let source = try String(
                contentsOf: root.appending(path: scriptPath),
                encoding: .utf8
            )

            #expect(source.contains("Contents/Resources/${RESOURCE_BUNDLE_NAME}"))
            #expect(source.contains("cp -R \"${RESOURCE_BUNDLE_SOURCE}\" \"${RESOURCE_BUNDLE_DESTINATION}\""))
            #expect(source.contains("/usr/bin/codesign --force --deep --sign - \"${BUNDLE_PATH}\""))
        }

        let releaseSource = try String(
            contentsOf: root.appending(path: "scripts/build_release.sh"),
            encoding: .utf8
        )
        #expect(releaseSource.contains("RELEASE_SIGNING_IDENTITY=\"C27D9B4458FF4C055F91B09861E39A3FB90771AB\""))
        #expect(releaseSource.contains("--options runtime"))
        #expect(releaseSource.contains("--sign \"${RELEASE_SIGNING_IDENTITY}\" \"${BUNDLE_PATH}\""))
    }

    @Test
    func packagedResourceLocatorPrefersTheAppResourcesDirectory() throws {
        let sourceURL = try repositoryRoot()
            .appending(path: "Sources/PetsCore/Pets/PetArtResourceLocator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Bundle.main.resourceURL?"))
        #expect(source.contains("Pets_PetsCore.bundle"))
        #expect(source.contains("return Bundle.module"))
    }

    private func repositoryRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while currentURL.path != "/" {
            if FileManager.default.fileExists(atPath: currentURL.appending(path: "Package.swift").path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
