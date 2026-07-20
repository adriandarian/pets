import Foundation
import SQLite3
import Testing
@testable import PetsCore

@Suite
struct CodexSessionScannerTests {
    private let now = ISO8601DateFormatter().date(from: "2026-07-20T20:30:00Z")!

    @Test
    func scannerFindsRecentCLIAndAppTasksWithTheirLatestState() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSession(
            root: root,
            name: "cli.jsonl",
            lines: [
                sessionMeta(id: "cli-task", source: "cli", threadSource: "user"),
                userMessage("Fix the login flow"),
                userMessage("<codex_internal_context>continue</codex_internal_context>"),
                taskEvent("task_started", timestamp: "2026-07-20T20:29:30Z"),
            ]
        )
        try writeSession(
            root: root,
            name: "app.jsonl",
            lines: [
                sessionMeta(id: "app-task", source: "vscode", threadSource: "user"),
                userMessage("Review the settings screen"),
                taskEvent("task_started", timestamp: "2026-07-20T20:28:00Z"),
                taskEvent("task_complete", timestamp: "2026-07-20T20:29:00Z"),
            ]
        )
        try writeSession(
            root: root,
            name: "exec.jsonl",
            lines: [
                sessionMeta(id: "exec-task", source: "exec", threadSource: "user"),
                userMessage("Run a one-off Codex command"),
                taskEvent("task_complete", timestamp: "2026-07-20T20:29:10Z"),
            ]
        )

        let sessions = try CodexSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now }
        ).scan()

        let cli = try #require(sessions.first(where: { $0.sessionID == "cli-task" }))
        let app = try #require(sessions.first(where: { $0.sessionID == "app-task" }))
        let exec = try #require(sessions.first(where: { $0.sessionID == "exec-task" }))
        #expect(cli.harnessID == PetTrackingProvider.codex.rawValue)
        #expect(cli.title == "Fix the login flow")
        #expect(cli.chatPreview == "Fix the login flow")
        #expect(cli.entrypoint == "Codex CLI")
        #expect(cli.status == .busy)
        #expect(app.entrypoint == "Codex app")
        #expect(app.status == .idle)
        #expect(exec.entrypoint == "Codex CLI")
    }

    @Test
    func scannerExcludesSubagentsAndStaleTasks() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSession(
            root: root,
            name: "subagent.jsonl",
            lines: [
                sessionMeta(id: "child", source: "vscode", threadSource: "subagent"),
                userMessage("Internal child work"),
                taskEvent("task_started", timestamp: "2026-07-20T20:29:00Z"),
            ]
        )
        let staleURL = try writeSession(
            root: root,
            name: "stale.jsonl",
            lines: [
                sessionMeta(id: "stale", source: "cli", threadSource: "user"),
                userMessage("Old task"),
            ]
        )
        try FileManager.default.setAttributes(
            [.modificationDate: ISO8601DateFormatter().date(from: "2026-07-20T18:00:00Z")!],
            ofItemAtPath: staleURL.path
        )

        let sessions = try CodexSessionScanner(
            roots: [root],
            recentSessionInterval: 30 * 60,
            now: { now }
        ).scan()

        #expect(sessions.isEmpty)
    }

    @Test
    func defaultLayoutOnlyWalksDateFoldersThatCanContainRecentSessions() throws {
        let codexHome = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: codexHome) }
        let sessionsRoot = codexHome.appending(path: "sessions", directoryHint: .isDirectory)
        let currentDay = sessionsRoot.appending(path: "2026/07/20", directoryHint: .isDirectory)
        let oldDay = sessionsRoot.appending(path: "2026/06/01", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: currentDay, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oldDay, withIntermediateDirectories: true)

        try writeSession(
            root: currentDay,
            name: "current.jsonl",
            lines: [
                sessionMeta(id: "current", source: "vscode", threadSource: "user"),
                userMessage("Current task"),
            ]
        )
        try writeSession(
            root: oldDay,
            name: "old-date.jsonl",
            lines: [
                sessionMeta(id: "old-date", source: "vscode", threadSource: "user"),
                userMessage("Should not be walked"),
            ]
        )

        let sessions = try CodexSessionScanner(
            recentSessionInterval: 30 * 60,
            now: { now },
            environment: ["CODEX_HOME": codexHome.path]
        ).scan()

        #expect(sessions.map(\.sessionID) == ["current"])
    }

    @Test
    func scannerUsesStoredCodexThreadTitleInsteadOfTheFirstPrompt() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let databaseURL = root.appending(path: "state_5.sqlite")
        try writeStateDatabase(
            at: databaseURL,
            titles: ["named-task": "Correct user-visible chat name"]
        )
        try writeSession(
            root: root,
            name: "named.jsonl",
            lines: [
                sessionMeta(id: "named-task", source: "vscode", threadSource: "user"),
                userMessage("This is the first prompt, not the chat name"),
            ]
        )

        let sessions = try CodexSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now },
            stateDatabaseURL: databaseURL
        ).scan()

        #expect(sessions.first?.title == "Correct user-visible chat name")
        #expect(sessions.first?.chatPreview == "This is the first prompt, not the chat name")
    }

    @Test
    func scannerCompactsThePromptWhenCodexHasNotGeneratedATitle() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let databaseURL = root.appending(path: "state_5.sqlite")
        let prompt = "/goal Current behavior is limited. I want to give the ability to track Codex and Copilot sessions. Preserve the existing behavior."
        try writeStateDatabase(
            at: databaseURL,
            threads: [
                "prompt-title": (title: prompt, firstUserMessage: prompt),
            ]
        )
        try writeSession(
            root: root,
            name: "prompt-title.jsonl",
            lines: [
                sessionMeta(id: "prompt-title", source: "vscode", threadSource: "user"),
                userMessage(prompt),
            ]
        )

        let sessions = try CodexSessionScanner(
            roots: [root],
            recentSessionInterval: 60 * 60,
            now: { now },
            stateDatabaseURL: databaseURL
        ).scan()

        #expect(sessions.first?.title == "Track Codex and Copilot sessions")
        #expect(sessions.first?.chatPreview == prompt)
    }

    private func sessionMeta(id: String, source: String, threadSource: String) -> String {
        #"{"timestamp":"2026-07-20T20:28:00Z","type":"session_meta","payload":{"id":"\#(id)","cwd":"/tmp/project","source":"\#(source)","thread_source":"\#(threadSource)"}}"#
    }

    private func userMessage(_ message: String) -> String {
        #"{"timestamp":"2026-07-20T20:28:10Z","type":"event_msg","payload":{"type":"user_message","message":"\#(message)"}}"#
    }

    private func taskEvent(_ type: String, timestamp: String) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"\#(type)"}}"#
    }

    @discardableResult
    private func writeSession(root: URL, name: String, lines: [String]) throws -> URL {
        let url = root.appending(path: name)
        try Data(lines.joined(separator: "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
        return url
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeStateDatabase(
        at url: URL,
        titles: [String: String]
    ) throws {
        try writeStateDatabase(
            at: url,
            threads: titles.mapValues { title in
                (title: title, firstUserMessage: "")
            }
        )
    }

    private func writeStateDatabase(
        at url: URL,
        threads: [String: (title: String, firstUserMessage: String)]
    ) throws {
        var database: OpaquePointer?
        #expect(sqlite3_open(url.path, &database) == SQLITE_OK)
        let openedDatabase = try #require(database)
        defer { sqlite3_close(openedDatabase) }

        #expect(sqlite3_exec(
            openedDatabase,
            "CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT NOT NULL, first_user_message TEXT NOT NULL)",
            nil,
            nil,
            nil
        ) == SQLITE_OK)

        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(
            openedDatabase,
            "INSERT INTO threads (id, title, first_user_message) VALUES (?1, ?2, ?3)",
            -1,
            &statement,
            nil
        ) == SQLITE_OK)
        let insertStatement = try #require(statement)
        defer { sqlite3_finalize(insertStatement) }

        for (sessionID, thread) in threads {
            sqlite3_reset(insertStatement)
            sqlite3_clear_bindings(insertStatement)
            _ = sessionID.withCString { value in
                sqlite3_bind_text(
                    insertStatement,
                    1,
                    value,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }
            _ = thread.title.withCString { value in
                sqlite3_bind_text(
                    insertStatement,
                    2,
                    value,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }
            _ = thread.firstUserMessage.withCString { value in
                sqlite3_bind_text(
                    insertStatement,
                    3,
                    value,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }
            #expect(sqlite3_step(insertStatement) == SQLITE_DONE)
        }
    }
}
