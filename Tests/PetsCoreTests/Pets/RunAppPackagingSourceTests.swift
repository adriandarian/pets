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
            "scripts/build_release.sh",
        ] {
            let source = try String(
                contentsOf: root.appending(path: scriptPath),
                encoding: .utf8
            )

            #expect(source.contains("Contents/Resources/${RESOURCE_BUNDLE_NAME}"))
            #expect(source.contains("cp -R \"${RESOURCE_BUNDLE_SOURCE}\" \"${RESOURCE_BUNDLE_DESTINATION}\""))
            #expect(source.contains("/usr/bin/codesign --force --deep --sign - \"${BUNDLE_PATH}\""))
        }
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
