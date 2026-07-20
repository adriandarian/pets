import Foundation
import SQLite3

public struct CodexSessionScanner: Sendable {
    private let roots: [URL]
    private let recentSessionInterval: TimeInterval
    private let maximumSessionCount: Int
    private let now: @Sendable () -> Date
    private let usesDatedSessionLayout: Bool
    private let stateDatabaseURL: URL?

    public init(
        roots: [URL]? = nil,
        recentSessionInterval: TimeInterval = 30 * 60,
        maximumSessionCount: Int = 12,
        now: @escaping @Sendable () -> Date = Date.init,
        stateDatabaseURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let home = environment["CODEX_HOME"].flatMap { value in
            value.isEmpty ? nil : URL(fileURLWithPath: value, isDirectory: true)
        } ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        self.roots = roots ?? [home.appendingPathComponent("sessions", isDirectory: true)]
        self.recentSessionInterval = recentSessionInterval
        self.maximumSessionCount = max(1, maximumSessionCount)
        self.now = now
        self.usesDatedSessionLayout = roots == nil
        self.stateDatabaseURL = stateDatabaseURL
            ?? (roots == nil ? home.appendingPathComponent("state_5.sqlite") : nil)
    }

    public func scan() throws -> [HarnessSession] {
        let currentDate = now()
        let sessions = try sessionFiles(now: currentDate)
            .compactMap { fileURL in
                try parseSession(at: fileURL, now: currentDate)
            }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(maximumSessionCount)
            .map { $0 }
        let storedTitles = CodexThreadTitleReader(databaseURL: stateDatabaseURL)
            .titles(for: Set(sessions.map(\.sessionID)))

        return sessions.map { session in
            guard let storedTitle = storedTitles[session.sessionID] else { return session }
            return Self.replacingTitle(
                in: session,
                with: Self.clamped(storedTitle, limit: 80)
            )
        }
    }

    private func sessionFiles(now: Date) throws -> [URL] {
        var files: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]

        for root in scanRoots(now: now) where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                files.append(fileURL)
            }
        }
        return files
    }

    private func scanRoots(now: Date) -> [URL] {
        guard usesDatedSessionLayout else { return roots }

        let calendar = Calendar.current
        let oldestRelevantDate = now.addingTimeInterval(-recentSessionInterval)
        let finalDay = calendar.startOfDay(for: now)
        var day = calendar.startOfDay(for: oldestRelevantDate)
        var dates: [Date] = []
        while day <= finalDay {
            dates.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return roots.flatMap { root in
            dates.compactMap { date in
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                guard let year = components.year,
                      let month = components.month,
                      let day = components.day
                else { return nil }
                let url = root
                    .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                    .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                    .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
                return url
            }
        }
    }

    private func parseSession(at url: URL, now: Date) throws -> HarnessSession? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modifiedAt = values.contentModificationDate,
              now.timeIntervalSince(modifiedAt) <= recentSessionInterval,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe)
        else { return nil }

        var accumulator = CodexSessionAccumulator()
        let decoder = JSONDecoder()
        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(CodexSessionEvent.self, from: Data(line)) else {
                continue
            }
            accumulator.consume(event)
        }

        guard let sessionID = accumulator.sessionID,
              accumulator.isUserSession
        else { return nil }

        let title = Self.fallbackTitle(from: accumulator.firstUserMessage)
        let preview = accumulator.latestUserMessage.map { Self.clamped($0, limit: 220) }
        let source = accumulator.source?.lowercased() ?? ""
        let entrypoint = source == "cli" || source == "exec" || source.contains("terminal")
            ? "Codex CLI"
            : "Codex app"

        return HarnessSession(
            harnessID: CodexHarness.defaultID,
            harnessDisplayName: CodexHarness.defaultDisplayName,
            sessionID: sessionID,
            processID: nil,
            cwd: accumulator.cwd ?? "",
            title: title,
            chatPreview: preview,
            dismissalToken: "\(accumulator.latestUserMessage ?? title)|\(modifiedAt.timeIntervalSince1970)",
            kind: "Codex task",
            entrypoint: entrypoint,
            status: accumulator.status,
            replyTarget: nil,
            updatedAt: accumulator.updatedAt ?? modifiedAt,
            startedAt: accumulator.startedAt
        )
    }

    private static func clamped(_ value: String, limit: Int) -> String {
        let cleaned = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard cleaned.count > limit else { return cleaned }
        return String(cleaned.prefix(max(1, limit - 1))) + "…"
    }

    private static func fallbackTitle(from firstUserMessage: String?) -> String {
        guard var title = firstUserMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else { return "Untitled Codex task" }

        if let requestMarker = title.range(
            of: "## My request for Codex:",
            options: [.caseInsensitive]
        ) {
            title = String(title[requestMarker.upperBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        title = removingLeadingCommandAndSkillLinks(from: title)

        let intentMarkers = [
            "I want to ",
            "I need you to ",
            "we need to ",
            "please ",
            "could you ",
            "can you ",
        ]
        for marker in intentMarkers {
            if let range = title.range(of: marker, options: [.caseInsensitive]) {
                title = String(title[range.upperBound...])
                break
            }
        }

        let fillerPrefixes = [
            "give the ability to ",
            "add the ability to ",
            "be able to ",
        ]
        for prefix in fillerPrefixes where title.lowercased().hasPrefix(prefix) {
            title.removeFirst(prefix.count)
            break
        }

        if let sentenceEnd = title.firstIndex(where: { ".!?\n".contains($0) }) {
            title = String(title[..<sentenceEnd])
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Untitled Codex task" }

        let firstCharacter = String(title.removeFirst()).uppercased()
        title = firstCharacter + title
        return clamped(title, limit: 80)
    }

    private static func removingLeadingCommandAndSkillLinks(from value: String) -> String {
        var value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("/"),
           let commandEnd = value.firstIndex(where: { $0.isWhitespace }) {
            value = String(value[commandEnd...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        while value.hasPrefix("[$"),
              let linkEnd = value.range(of: ")")?.upperBound {
            value = String(value[linkEnd...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private static func replacingTitle(
        in session: HarnessSession,
        with title: String
    ) -> HarnessSession {
        HarnessSession(
            harnessID: session.harnessID,
            harnessDisplayName: session.harnessDisplayName,
            sessionID: session.sessionID,
            processID: session.processID,
            cwd: session.cwd,
            title: title,
            chatPreview: session.chatPreview,
            dismissalToken: session.dismissalToken,
            kind: session.kind,
            entrypoint: session.entrypoint,
            status: session.status,
            replyTarget: session.replyTarget,
            updatedAt: session.updatedAt,
            startedAt: session.startedAt
        )
    }
}

private struct CodexThreadTitleReader {
    let databaseURL: URL?

    func titles(for sessionIDs: Set<String>) -> [String: String] {
        guard let databaseURL,
              !sessionIDs.isEmpty,
              FileManager.default.isReadableFile(atPath: databaseURL.path)
        else { return [:] }

        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        ) == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            return [:]
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 50)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database,
            "SELECT title, first_user_message FROM threads WHERE id = ?1 LIMIT 1",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        var titles: [String: String] = [:]
        for sessionID in sessionIDs {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            _ = sessionID.withCString { value in
                sqlite3_bind_text(
                    statement,
                    1,
                    value,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }

            guard sqlite3_step(statement) == SQLITE_ROW,
                  let rawTitle = sqlite3_column_text(statement, 0)
            else { continue }
            let title = String(cString: rawTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let firstUserMessage = sqlite3_column_text(statement, 1).map(String.init(cString:))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, title != firstUserMessage {
                titles[sessionID] = title
            }
        }
        return titles
    }
}

private struct CodexSessionAccumulator {
    var sessionID: String?
    var cwd: String?
    var source: String?
    var threadSource: String?
    var firstUserMessage: String?
    var latestUserMessage: String?
    var status: HarnessSessionStatus = .idle
    var updatedAt: Date?
    var startedAt: Date?

    var isUserSession: Bool {
        threadSource?.lowercased() != "subagent"
    }

    mutating func consume(_ event: CodexSessionEvent) {
        if let timestamp = CodexSessionEvent.date(from: event.timestamp) {
            updatedAt = timestamp
            if startedAt == nil {
                startedAt = timestamp
            }
        }

        switch event.type {
        case "session_meta":
            sessionID = event.payload?.id ?? event.payload?.sessionID ?? sessionID
            cwd = event.payload?.cwd ?? cwd
            source = event.payload?.source ?? source
            threadSource = event.payload?.threadSource ?? threadSource

        case "event_msg":
            switch event.payload?.type {
            case "user_message":
                recordUserMessage(event.payload?.message)
            case "task_started":
                status = .busy
            case "task_complete", "turn_aborted":
                status = .idle
            default:
                break
            }

        case "response_item":
            if event.payload?.role == "user" {
                recordUserMessage(event.payload?.content?.compactMap(\.text).joined(separator: " "))
            }

        default:
            break
        }
    }

    private mutating func recordUserMessage(_ message: String?) {
        guard let message else { return }
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !cleaned.hasPrefix("<codex_internal_context"),
              !cleaned.hasPrefix("<environment_context"),
              !cleaned.hasPrefix("<recommended_plugins")
        else { return }
        if firstUserMessage == nil {
            firstUserMessage = cleaned
        }
        latestUserMessage = cleaned
    }
}

private struct CodexSessionEvent: Decodable {
    struct Payload: Decodable {
        let type: String?
        let id: String?
        let sessionID: String?
        let cwd: String?
        let source: String?
        let threadSource: String?
        let message: String?
        let role: String?
        let content: [Content]?

        private enum CodingKeys: String, CodingKey {
            case type
            case id
            case sessionID = "session_id"
            case cwd
            case source
            case threadSource = "thread_source"
            case message
            case role
            case content
        }
    }

    struct Content: Decodable {
        let text: String?
    }

    let type: String
    let timestamp: String?
    let payload: Payload?

    static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
