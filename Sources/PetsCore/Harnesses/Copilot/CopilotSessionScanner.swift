import Foundation

public struct CopilotSessionScanner: Sendable {
    private let roots: [URL]
    private let recentSessionInterval: TimeInterval
    private let maximumSessionCount: Int
    private let now: @Sendable () -> Date

    public init(
        roots: [URL]? = nil,
        recentSessionInterval: TimeInterval = 30 * 60,
        maximumSessionCount: Int = 12,
        now: @escaping @Sendable () -> Date = Date.init,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let home = environment["COPILOT_HOME"].flatMap { value in
            value.isEmpty ? nil : URL(fileURLWithPath: value, isDirectory: true)
        } ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".copilot", isDirectory: true)
        self.roots = roots ?? [home.appendingPathComponent("session-state", isDirectory: true)]
        self.recentSessionInterval = recentSessionInterval
        self.maximumSessionCount = max(1, maximumSessionCount)
        self.now = now
    }

    public func scan() throws -> [HarnessSession] {
        let currentDate = now()
        return canonicalSessionFiles()
            .compactMap { candidate in
                parseSession(candidate, now: currentDate)
            }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(maximumSessionCount)
            .map { $0 }
    }

    private func canonicalSessionFiles() -> [CopilotSessionCandidate] {
        var candidates: [String: CopilotSessionCandidate] = [:]

        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                let candidate: CopilotSessionCandidate
                let priority: Int

                if values?.isDirectory == true {
                    let eventsURL = entry.appendingPathComponent("events.jsonl")
                    guard FileManager.default.isReadableFile(atPath: eventsURL.path) else { continue }
                    candidate = CopilotSessionCandidate(
                        sessionID: entry.lastPathComponent,
                        eventsURL: eventsURL,
                        workspaceURL: entry.appendingPathComponent("workspace.yaml"),
                        isVSCodeChat: Self.hasVSCodeMetadata(in: entry)
                            || Self.workspaceClientName(
                                from: entry.appendingPathComponent("workspace.yaml")
                            ) == "vscode"
                    )
                    priority = 2
                } else if values?.isRegularFile == true, entry.pathExtension == "jsonl" {
                    candidate = CopilotSessionCandidate(
                        sessionID: entry.deletingPathExtension().lastPathComponent,
                        eventsURL: entry,
                        workspaceURL: nil,
                        isVSCodeChat: false
                    )
                    priority = 1
                } else {
                    continue
                }

                if candidates[candidate.sessionID] == nil || priority == 2 {
                    candidates[candidate.sessionID] = candidate
                }
            }
        }
        return Array(candidates.values)
    }

    private func parseSession(
        _ candidate: CopilotSessionCandidate,
        now: Date
    ) -> HarnessSession? {
        guard let values = try? candidate.eventsURL.resourceValues(forKeys: [.contentModificationDateKey]),
              let modifiedAt = values.contentModificationDate,
              now.timeIntervalSince(modifiedAt) <= recentSessionInterval,
              let data = try? Data(contentsOf: candidate.eventsURL, options: .mappedIfSafe)
        else { return nil }

        var accumulator = CopilotSessionAccumulator(sessionID: candidate.sessionID)
        let decoder = JSONDecoder()
        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(CopilotSessionEvent.self, from: Data(line)) else {
                continue
            }
            accumulator.consume(event)
        }

        let title = accumulator.firstUserMessage
            .map { Self.clamped($0, limit: 80) }
            ?? "Untitled Copilot chat"
        let preview = accumulator.latestUserMessage.map { Self.clamped($0, limit: 220) }
        let entrypoint = candidate.isVSCodeChat ? "Copilot chat" : "Copilot CLI"

        return HarnessSession(
            harnessID: CopilotHarness.defaultID,
            harnessDisplayName: CopilotHarness.defaultDisplayName,
            sessionID: accumulator.sessionID,
            processID: nil,
            cwd: Self.workspacePath(from: candidate.workspaceURL) ?? "",
            title: title,
            chatPreview: preview,
            dismissalToken: "\(accumulator.latestUserMessage ?? title)|\(modifiedAt.timeIntervalSince1970)",
            kind: "Copilot session",
            entrypoint: entrypoint,
            status: accumulator.status,
            replyTarget: nil,
            updatedAt: accumulator.updatedAt ?? modifiedAt,
            startedAt: accumulator.startedAt
        )
    }

    private static func hasVSCodeMetadata(in directory: URL) -> Bool {
        if FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("session.db").path
        ) || FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("vscode.requests.metadata.json").path
        ) {
            return true
        }

        let url = directory.appendingPathComponent("vscode.metadata.json")
        guard let data = try? Data(contentsOf: url) else { return false }
        let content = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !content.isEmpty && content != "[]" && content != "{}"
    }

    private static func workspaceClientName(from url: URL) -> String? {
        yamlValue(named: ["client_name", "clientName"], from: url)?.lowercased()
    }

    private static func workspacePath(from url: URL?) -> String? {
        guard let url else { return nil }
        return yamlValue(named: ["cwd"], from: url)
    }

    private static func yamlValue(named keys: Set<String>, from url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  keys.contains(parts[0].trimmingCharacters(in: .whitespaces))
            else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private static func clamped(_ value: String, limit: Int) -> String {
        let cleaned = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard cleaned.count > limit else { return cleaned }
        return String(cleaned.prefix(max(1, limit - 1))) + "…"
    }
}

private struct CopilotSessionCandidate {
    let sessionID: String
    let eventsURL: URL
    let workspaceURL: URL?
    let isVSCodeChat: Bool
}

private struct CopilotSessionAccumulator {
    var sessionID: String
    var firstUserMessage: String?
    var latestUserMessage: String?
    var status: HarnessSessionStatus = .idle
    var updatedAt: Date?
    var startedAt: Date?

    mutating func consume(_ event: CopilotSessionEvent) {
        if let timestamp = CopilotSessionEvent.date(from: event.timestamp) {
            updatedAt = timestamp
            if startedAt == nil {
                startedAt = timestamp
            }
        }

        switch event.type {
        case "session.start", "session.resume":
            sessionID = event.data?.sessionID ?? sessionID
            status = .idle
        case "user.message", "assistant.turn_start", "tool.execution_start", "permission.completed":
            if event.type == "user.message" {
                recordUserMessage(event.data?.content)
            }
            status = .busy
        case "assistant.turn_end":
            status = .idle
        case "permission.requested":
            status = .waiting
        case "session.shutdown":
            status = .idle
        default:
            break
        }
    }

    private mutating func recordUserMessage(_ message: String?) {
        guard let message else { return }
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if firstUserMessage == nil {
            firstUserMessage = cleaned
        }
        latestUserMessage = cleaned
    }
}

private struct CopilotSessionEvent: Decodable {
    struct Payload: Decodable {
        let sessionID: String?
        let content: String?

        private enum CodingKeys: String, CodingKey {
            case sessionID
            case content
        }
    }

    let type: String
    let timestamp: String?
    let data: Payload?

    static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
