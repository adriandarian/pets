import Darwin
import Foundation

public protocol ProcessInspecting: Sendable {
    func isProcessAlive(pid: Int32) -> Bool
    func terminalName(pid: Int32) -> String?
}

public struct DarwinProcessInspector: ProcessInspecting {
    public init() {}

    public func isProcessAlive(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }

    public func terminalName(pid: Int32) -> String? {
        guard pid > 0 else { return nil }

        let process = Process()
        process.executableURL = URL(filePath: "/bin/ps")
        process.arguments = ["-o", "tty=", "-p", "\(pid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let tty = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !tty.isEmpty, tty != "??" else { return nil }
        return tty
    }
}

public struct ClaudeSessionScanner: Sendable {
    private let claudeHome: URL
    private let processInspector: any ProcessInspecting
    private let now: @Sendable () -> Date
    private let recentActivityInterval: TimeInterval

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory),
        processInspector: any ProcessInspecting = DarwinProcessInspector(),
        recentActivityInterval: TimeInterval = 120,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.claudeHome = claudeHome
        self.processInspector = processInspector
        self.recentActivityInterval = recentActivityInterval
        self.now = now
    }

    public func scan() throws -> [ClaudeSession] {
        let sessionFiles = try sessionJSONFiles()
        let currentDate = now()

        return sessionFiles.compactMap { file in
            guard let rawSession = try? decodeSessionFile(at: file),
                  processInspector.isProcessAlive(pid: rawSession.pid)
            else {
                return nil
            }

            return rawSession.toSession(
                now: currentDate,
                recentActivityInterval: recentActivityInterval,
                transcriptSummary: transcriptSummary(for: rawSession),
                replyTarget: rawSession.replyTarget(processInspector: processInspector)
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.updatedAt, rhs.updatedAt) {
            case let (left?, right?):
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.startedAt ?? .distantPast > rhs.startedAt ?? .distantPast
            }
        }
    }

    private func sessionJSONFiles() throws -> [URL] {
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: sessionsDirectory.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
    }

    private func decodeSessionFile(at url: URL) throws -> RawClaudeSession {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RawClaudeSession.self, from: data)
    }

    private func transcriptSummary(for session: RawClaudeSession) -> TranscriptSummary {
        let transcriptURL = claudeHome
            .appending(path: "projects", directoryHint: .isDirectory)
            .appending(path: projectDirectoryName(for: session.cwd), directoryHint: .isDirectory)
            .appending(path: "\(session.sessionId).jsonl")

        guard let data = try? Data(contentsOf: transcriptURL),
              let contents = String(data: data, encoding: .utf8)
        else {
            return TranscriptSummary()
        }

        let decoder = JSONDecoder()
        let entries = contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> RawTranscriptEntry? in
                guard let lineData = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(RawTranscriptEntry.self, from: lineData)
            }

        return TranscriptSummary(
            title: entries.reversed().compactMap(\.cleanAITitle).first
                ?? entries.reversed().compactMap(\.cleanLastPrompt).first,
            chatPreview: entries.compactMap(\.cleanChatPreview).first
                ?? entries.compactMap(\.cleanLastPrompt).first,
            dismissalToken: entries.reversed().compactMap(\.cleanPromptToken).first
        )
    }

    private func projectDirectoryName(for cwd: String) -> String {
        let directoryName = cwd.replacingOccurrences(of: "/", with: "-")
        return directoryName.isEmpty ? "-" : directoryName
    }
}

private struct RawClaudeSession: Decodable {
    let pid: Int32
    let sessionId: String
    let cwd: String
    let startedAt: Int?
    let kind: String
    let entrypoint: String
    let name: String?
    let jobId: String?
    let status: String?
    let updatedAt: Int?

    func toSession(
        now: Date,
        recentActivityInterval: TimeInterval,
        transcriptSummary: TranscriptSummary,
        replyTarget: ClaudeReplyTarget?
    ) -> ClaudeSession {
        let updatedAtDate = updatedAt.flatMap(Self.dateFromClaudeMilliseconds)
        return ClaudeSession(
            pid: pid,
            sessionId: sessionId,
            cwd: cwd,
            title: title(transcriptTitle: transcriptSummary.title),
            chatPreview: transcriptSummary.chatPreview,
            dismissalToken: transcriptSummary.dismissalToken,
            kind: kind,
            entrypoint: entrypoint,
            displayStatus: displayStatus(now: now, updatedAt: updatedAtDate, recentActivityInterval: recentActivityInterval),
            replyTarget: replyTarget,
            updatedAt: updatedAtDate,
            startedAt: startedAt.flatMap(Self.dateFromClaudeMilliseconds)
        )
    }

    func replyTarget(processInspector: any ProcessInspecting) -> ClaudeReplyTarget? {
        if let jobId, !jobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .background(id: jobId)
        }

        guard kind.lowercased() == "interactive",
              let tty = processInspector.terminalName(pid: pid)
        else {
            return nil
        }

        return .terminal(tty: tty)
    }

    private func title(transcriptTitle: String?) -> String {
        if let transcriptTitle, !transcriptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transcriptTitle
        }

        if let metadataName {
            return metadataName
        }

        return "Untitled chat"
    }

    private var metadataName: String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else { return nil }
        return trimmed
    }

    private func displayStatus(
        now: Date,
        updatedAt: Date?,
        recentActivityInterval: TimeInterval
    ) -> ClaudeDisplayStatus {
        switch status?.lowercased() {
        case "busy", "running", "working":
            return .busy
        case "waiting", "blocked":
            return .waiting
        case "idle", "ready":
            return .idle
        case .some:
            return .unknown
        case .none:
            guard let updatedAt else { return .unknown }
            return now.timeIntervalSince(updatedAt) <= recentActivityInterval ? .busy : .idle
        }
    }

    private static func dateFromClaudeMilliseconds(_ milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

private struct TranscriptSummary {
    var title: String?
    var chatPreview: String?
    var dismissalToken: String?
}

private struct RawTranscriptEntry: Decodable {
    let type: String?
    let aiTitle: String?
    let lastPrompt: String?
    let message: RawTranscriptMessage?

    var cleanAITitle: String? {
        clean(aiTitle)
    }

    var cleanLastPrompt: String? {
        clean(lastPrompt)
    }

    var cleanChatPreview: String? {
        guard type == "user" || message?.role == "user" else { return nil }
        return clean(message?.textContent)
    }

    var cleanPromptToken: String? {
        cleanLastPrompt ?? cleanChatPreview
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RawTranscriptMessage: Decodable {
    let role: String?
    let content: RawTranscriptContent?

    var textContent: String? {
        content?.text
    }
}

private enum RawTranscriptContent: Decodable {
    case text(String)
    case blocks([RawTranscriptContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }

        self = .blocks((try? container.decode([RawTranscriptContentBlock].self)) ?? [])
    }

    var text: String? {
        switch self {
        case let .text(text):
            return text
        case let .blocks(blocks):
            let text = blocks
                .filter { $0.type == nil || $0.type == "text" }
                .compactMap(\.text)
                .joined(separator: " ")
            return text.isEmpty ? nil : text
        }
    }
}

private struct RawTranscriptContentBlock: Decodable {
    let type: String?
    let text: String?
}
