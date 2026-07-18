import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetsReleaseTests {
    @Test
    func semanticVersionsIgnoreTheLeadingVAndCompareNumerically() throws {
        let current = try #require(PetsVersion("1.9.9"))
        let latest = try #require(PetsVersion("v1.10.0"))

        #expect(latest > current)
        #expect(PetsVersion("v1.2") == PetsVersion("1.2.0"))
    }

    @Test
    func parserReturnsANewerGitHubRelease() throws {
        let data = Data(#"""
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/adriandarian/pets/releases/tag/v0.2.0",
          "name": "Pets 0.2.0",
          "body": "New pets and fixes."
        }
        """#.utf8)

        let release = try PetsReleaseParser.newerRelease(
            from: data,
            than: "0.1.0"
        )

        #expect(release?.displayVersion == "0.2.0")
        #expect(release?.releaseNotes == "New pets and fixes.")
        #expect(release?.htmlURL.absoluteString == "https://github.com/adriandarian/pets/releases/tag/v0.2.0")
    }

    @Test
    func parserReturnsNilForTheInstalledOrAnOlderVersion() throws {
        let current = Data(#"{"tag_name":"v1.2.0","html_url":"https://example.com/current"}"#.utf8)
        let older = Data(#"{"tag_name":"v1.1.9","html_url":"https://example.com/older"}"#.utf8)

        #expect(try PetsReleaseParser.newerRelease(from: current, than: "1.2.0") == nil)
        #expect(try PetsReleaseParser.newerRelease(from: older, than: "1.2.0") == nil)
    }

    @Test
    func parserRejectsMalformedVersionsAndURLs() {
        let invalidVersion = Data(#"{"tag_name":"latest","html_url":"https://example.com/latest"}"#.utf8)
        let invalidURL = Data(#"{"tag_name":"v1.2.0","html_url":"not a release URL"}"#.utf8)

        #expect(throws: PetsReleaseError.invalidReleaseVersion("latest")) {
            try PetsReleaseParser.newerRelease(from: invalidVersion, than: "1.0.0")
        }
        #expect(throws: PetsReleaseError.invalidReleaseURL) {
            try PetsReleaseParser.newerRelease(from: invalidURL, than: "1.0.0")
        }
    }
}
