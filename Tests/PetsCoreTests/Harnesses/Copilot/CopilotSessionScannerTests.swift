import Foundation
import Testing
@testable import PetsCore

@Suite
struct CopilotSessionScannerTests {
    private let now = ISO8601DateFormatter().date(from: "2026-07-20T20:30:00Z")!

    @Test
    func scannerFindsCLIAndVSCodeChatsAndReadsWorkspaceContext() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSession(
            id: "cli-session",
            root: root,
            lines: [
                sessionStart("cli-session"),
                userMessage("Implement the command"),
                event("assistant.turn_start", timestamp: "2026-07-20T20:29:30Z"),
            ],
            cwd: "/tmp/cli-project"
        )
        try writeSession(
            id: "chat-session",
            root: root,
            lines: [
                sessionStart("chat-session"),
                userMessage("Explain this selection"),
                event("assistant.turn_start", timestamp: "2026-07-20T20:28:30Z"),
                event("assistant.turn_end", timestamp: "2026-07-20T20:29:00Z"),
            ],
            cwd: "/tmp/chat-project",
            vscodeMetadata: #"{"workspace":"chat"}"#
        )

        let sessions = try CopilotSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now }
        ).scan()

        let cli = try #require(sessions.first(where: { $0.sessionID == "cli-session" }))
        let chat = try #require(sessions.first(where: { $0.sessionID == "chat-session" }))
        #expect(cli.harnessID == PetTrackingProvider.githubCopilot.rawValue)
        #expect(cli.title == "Implement the command")
        #expect(cli.cwd == "/tmp/cli-project")
        #expect(cli.entrypoint == "Copilot CLI")
        #expect(cli.status == .busy)
        #expect(chat.entrypoint == "Copilot chat")
        #expect(chat.status == .idle)
    }

    @Test
    func modernDirectoryWinsOverDuplicateLegacyFile() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appending(path: "same-id.jsonl")
        try Data([
            sessionStart("same-id"),
            userMessage("Legacy copy"),
        ].joined(separator: "\n").utf8).write(to: legacy)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: legacy.path)
        try writeSession(
            id: "same-id",
            root: root,
            lines: [
                sessionStart("same-id"),
                userMessage("Canonical chat"),
                event("assistant.turn_end", timestamp: "2026-07-20T20:29:00Z"),
            ],
            cwd: "/tmp/project"
        )

        let sessions = try CopilotSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now }
        ).scan()

        #expect(sessions.count == 1)
        #expect(sessions.first?.title == "Canonical chat")
    }

    @Test
    func workspaceClientMetadataIdentifiesVSCodeChats() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSession(
            id: "vscode-workspace",
            root: root,
            lines: [
                sessionStart("vscode-workspace"),
                userMessage("Chat from VS Code"),
            ],
            cwd: "/tmp/project",
            clientName: "vscode"
        )

        let sessions = try CopilotSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now }
        ).scan()

        #expect(sessions.first?.entrypoint == "Copilot chat")
    }

    private func sessionStart(_ id: String) -> String {
        #"{"type":"session.start","timestamp":"2026-07-20T20:28:00Z","data":{"sessionId":"\#(id)"}}"#
    }

    private func userMessage(_ message: String) -> String {
        #"{"type":"user.message","timestamp":"2026-07-20T20:28:10Z","data":{"content":"\#(message)"}}"#
    }

    private func event(_ type: String, timestamp: String) -> String {
        #"{"type":"\#(type)","timestamp":"\#(timestamp)","data":{}}"#
    }

    private func writeSession(
        id: String,
        root: URL,
        lines: [String],
        cwd: String,
        vscodeMetadata: String? = nil,
        clientName: String? = nil
    ) throws {
        let directory = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let eventsURL = directory.appending(path: "events.jsonl")
        try Data(lines.joined(separator: "\n").utf8).write(to: eventsURL)
        var workspace = "cwd: \(cwd)\n"
        if let clientName {
            workspace += "client_name: \(clientName)\n"
        }
        try Data(workspace.utf8).write(to: directory.appending(path: "workspace.yaml"))
        if let vscodeMetadata {
            try Data(vscodeMetadata.utf8).write(to: directory.appending(path: "vscode.metadata.json"))
        }
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: eventsURL.path)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
