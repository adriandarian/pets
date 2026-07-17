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

        var processInfo = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(
            pid,
            PROC_PIDTBSDINFO,
            0,
            &processInfo,
            expectedSize
        ) == expectedSize,
              processInfo.e_tdev != UInt32.max,
              let terminalName = devname(
                  dev_t(bitPattern: processInfo.e_tdev),
                  S_IFCHR
              )
        else {
            return nil
        }

        return String(cString: terminalName)
    }
}

public struct ClaudeSessionScanner: Sendable {
    private let claudeHome: URL
    private let processInspector: any ProcessInspecting
    private let now: @Sendable () -> Date
    private let recentActivityInterval: TimeInterval
    private let transcriptSummaryCache: TranscriptSummaryCache

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
        self.transcriptSummaryCache = TranscriptSummaryCache()
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

        guard let signature = TranscriptFileSignature(url: transcriptURL) else {
            return TranscriptSummary()
        }

        if let cached = transcriptSummaryCache.entry(for: transcriptURL) {
            if cached.signature == signature {
                return cached.accumulator.summary
            }

            if signature.fileSize > cached.signature.fileSize,
               cached.processedByteCount <= signature.fileSize,
               let appendedData = readTranscriptData(
                   at: transcriptURL,
                   startingAt: cached.processedByteCount
               )
            {
                var accumulator = cached.accumulator
                let consumedByteCount = accumulator.consume(appendedData)
                transcriptSummaryCache.store(
                    TranscriptCacheEntry(
                        signature: signature,
                        processedByteCount: cached.processedByteCount + consumedByteCount,
                        accumulator: accumulator
                    ),
                    for: transcriptURL
                )
                return accumulator.summary
            }
        }

        guard let data = readTranscriptData(at: transcriptURL, startingAt: 0) else {
            return TranscriptSummary()
        }

        var accumulator = TranscriptAccumulator()
        let consumedByteCount = accumulator.consume(data)
        transcriptSummaryCache.store(
            TranscriptCacheEntry(
                signature: signature,
                processedByteCount: consumedByteCount,
                accumulator: accumulator
            ),
            for: transcriptURL
        )
        return accumulator.summary
    }

    private func readTranscriptData(at url: URL, startingAt: Int) -> Data? {
        guard startingAt >= 0,
              let handle = try? FileHandle(forReadingFrom: url)
        else {
            return nil
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: UInt64(startingAt))
            return try handle.readToEnd() ?? Data()
        } catch {
            return nil
        }
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

private struct TranscriptAccumulator {
    private var latestAITitle: String?
    private var latestLastPrompt: String?
    private var firstChatPreview: String?
    private var firstLastPrompt: String?
    private var latestPromptToken: String?

    var summary: TranscriptSummary {
        TranscriptSummary(
            title: latestAITitle ?? latestLastPrompt,
            chatPreview: firstChatPreview ?? firstLastPrompt,
            dismissalToken: latestPromptToken
        )
    }

    mutating func consume(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        var lineStart = data.startIndex

        while lineStart < data.endIndex,
              let newline = data[lineStart...].firstIndex(of: 0x0A)
        {
            consume(data[lineStart..<newline], decoder: decoder)
            lineStart = data.index(after: newline)
        }

        guard lineStart < data.endIndex else {
            return data.count
        }

        let trailingLine = data[lineStart..<data.endIndex]
        guard consume(trailingLine, decoder: decoder) else {
            return data.distance(from: data.startIndex, to: lineStart)
        }
        return data.count
    }

    @discardableResult
    private mutating func consume(
        _ line: Data.SubSequence,
        decoder: JSONDecoder
    ) -> Bool {
        guard !line.isEmpty,
              let entry = try? decoder.decode(RawTranscriptEntry.self, from: Data(line))
        else {
            return false
        }

        if let title = entry.cleanAITitle {
            latestAITitle = title
        }
        if let prompt = entry.cleanLastPrompt {
            latestLastPrompt = prompt
            if firstLastPrompt == nil {
                firstLastPrompt = prompt
            }
        }
        if firstChatPreview == nil, let preview = entry.cleanChatPreview {
            firstChatPreview = preview
        }
        if let promptToken = entry.cleanPromptToken {
            latestPromptToken = promptToken
        }
        return true
    }
}

private struct TranscriptFileSignature: Equatable, Sendable {
    let fileSize: Int
    let modificationDate: Date

    init?(url: URL) {
        guard let values = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
        ]),
        let fileSize = values.fileSize,
        let modificationDate = values.contentModificationDate
        else {
            return nil
        }

        self.fileSize = fileSize
        self.modificationDate = modificationDate
    }
}

private struct TranscriptCacheEntry {
    let signature: TranscriptFileSignature
    let processedByteCount: Int
    let accumulator: TranscriptAccumulator
}

private final class TranscriptSummaryCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [URL: TranscriptCacheEntry] = [:]

    func entry(for url: URL) -> TranscriptCacheEntry? {
        lock.withLock {
            entries[url]
        }
    }

    func store(_ entry: TranscriptCacheEntry, for url: URL) {
        lock.withLock {
            entries[url] = entry
        }
    }
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
