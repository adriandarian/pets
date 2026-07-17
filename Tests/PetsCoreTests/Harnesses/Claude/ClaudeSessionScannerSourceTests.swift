import Foundation
import Testing

@Suite
struct ClaudeSessionScannerSourceTests {
    @Test
    func terminalLookupUsesDirectDarwinProcessInfoWithoutSpawningPS() throws {
        let sourceURL = try repositoryRoot()
            .appending(path: "Sources/PetsCore/Harnesses/Claude/ClaudeSessionScanner.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("proc_pidinfo("))
        #expect(source.contains("PROC_PIDTBSDINFO"))
        #expect(source.contains("devname("))
        #expect(!source.contains("process.executableURL = URL(filePath: \"/bin/ps\")"))
        #expect(!source.contains("process.waitUntilExit()"))
    }

    @Test
    func growingTranscriptsResumeAtTheCachedByteOffset() throws {
        let sourceURL = try repositoryRoot()
            .appending(path: "Sources/PetsCore/Harnesses/Claude/ClaudeSessionScanner.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("FileHandle(forReadingFrom:"))
        #expect(source.contains("processedByteCount"))
        #expect(source.contains("seek(toOffset: UInt64(startingAt))"))
        #expect(!source.contains("Data(contentsOf: transcriptURL)"))
    }

    private func repositoryRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while currentURL.path != "/" {
            if FileManager.default.fileExists(
                atPath: currentURL.appending(path: "Package.swift").path
            ) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
