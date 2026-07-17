import Foundation
import Testing

@Suite
struct RunAppPackagingSourceTests {
    @Test
    func packagedAppCarriesTheSwiftPMResourceBundle() throws {
        let scriptURL = try repositoryRoot().appending(path: "scripts/run_app.sh")
        let source = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(source.contains("RESOURCE_BUNDLE_NAME=\"${APP_NAME}_PetsCore.bundle\""))
        #expect(source.contains("RESOURCE_BUNDLE_SOURCE=\".build/debug/${RESOURCE_BUNDLE_NAME}\""))
        #expect(source.contains("cp -R \"${RESOURCE_BUNDLE_SOURCE}\" \"${BUNDLE_PATH}/${RESOURCE_BUNDLE_NAME}\""))
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
