import Foundation

public struct CopilotUsagePeriod: Equatable, Sendable {
    public let id: String
    public let interval: DateInterval

    public init(containing date: Date = Date(), calendar: Calendar = .current) {
        var weeklyCalendar = calendar
        weeklyCalendar.firstWeekday = 2
        let interval = weeklyCalendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
        self.interval = interval

        let formatter = DateFormatter()
        formatter.calendar = weeklyCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = weeklyCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: interval.start)
    }
}

public enum CopilotUsageParser {
    private struct Event: Decodable {
        struct Payload: Decodable {
            struct TokenDetails: Decodable, Hashable {
                struct TokenCount: Decodable, Hashable {
                    let tokenCount: Int64
                }

                let input: TokenCount?
                let cacheRead: TokenCount?
                let cacheWrite: TokenCount?
                let output: TokenCount?

                private enum CodingKeys: String, CodingKey {
                    case input
                    case cacheRead = "cache_read"
                    case cacheWrite = "cache_write"
                    case output
                }

                var total: Int64 {
                    [input, cacheRead, cacheWrite, output].reduce(into: 0) { total, value in
                        guard let value else { return }
                        total = CopilotUsageParser.addingClamped(
                            total,
                            max(0, value.tokenCount)
                        )
                    }
                }
            }

            let outputTokens: Int64?
            let tokenDetails: TokenDetails?
        }

        let type: String
        let timestamp: String
        let data: Payload?
    }

    private struct ShutdownIdentity: Hashable {
        let timestamp: String
        let tokenDetails: Event.Payload.TokenDetails
    }

    public static func tokens(in data: Data, interval: DateInterval) -> Int64 {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        var committedTokens: Int64 = 0
        var trailingOutputTokens: Int64 = 0
        var seenShutdowns: Set<ShutdownIdentity> = []

        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(Event.self, from: Data(line)),
                  let date = parseTimestamp(
                      event.timestamp,
                      fractionalFormatter: fractionalFormatter,
                      standardFormatter: standardFormatter
                  ),
                  date >= interval.start,
                  date < interval.end
            else { continue }

            switch event.type {
            case "assistant.message":
                trailingOutputTokens = addingClamped(
                    trailingOutputTokens,
                    max(0, event.data?.outputTokens ?? 0)
                )

            case "session.shutdown":
                guard let tokenDetails = event.data?.tokenDetails else { continue }
                let identity = ShutdownIdentity(
                    timestamp: event.timestamp,
                    tokenDetails: tokenDetails
                )
                if seenShutdowns.insert(identity).inserted {
                    committedTokens = addingClamped(committedTokens, tokenDetails.total)
                    trailingOutputTokens = 0
                }

            default:
                continue
            }
        }

        return addingClamped(committedTokens, trailingOutputTokens)
    }

    private static func parseTimestamp(
        _ value: String,
        fractionalFormatter: ISO8601DateFormatter,
        standardFormatter: ISO8601DateFormatter
    ) -> Date? {
        fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }

    private static func addingClamped(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int64.max : result.partialValue
    }
}

public struct CopilotUsageSource: PetUsageSource {
    public let id = "copilot"
    public let displayName = "GitHub Copilot"
    private let roots: [URL]
    private let date: Date
    private let calendar: Calendar

    public init(
        roots: [URL]? = nil,
        date: Date = Date(),
        calendar: Calendar = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let home: URL
        if let configuredHome = environment["COPILOT_HOME"], !configuredHome.isEmpty {
            home = URL(fileURLWithPath: configuredHome, isDirectory: true)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".copilot", isDirectory: true)
        }
        self.roots = roots ?? [home.appendingPathComponent("session-state", isDirectory: true)]
        self.date = date
        self.calendar = calendar
    }

    public func read() throws -> PetUsageReading {
        let period = CopilotUsagePeriod(containing: date, calendar: calendar)
        let sessionFiles = canonicalSessionFiles()
        var total: Int64 = 0

        for fileURL in sessionFiles.values {
            guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
                continue
            }
            let fileTokens = CopilotUsageParser.tokens(in: data, interval: period.interval)
            let result = total.addingReportingOverflow(fileTokens)
            total = result.overflow ? Int64.max : result.partialValue
        }

        return PetUsageReading(providerID: id, periodID: period.id, tokens: total)
    }

    private func canonicalSessionFiles() -> [String: URL] {
        struct Candidate {
            let url: URL
            let priority: Int
        }

        var candidates: [String: Candidate] = [:]
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .isRegularFileKey,
                ])
                let sessionID: String
                let eventsURL: URL
                let priority: Int

                if values?.isDirectory == true {
                    sessionID = entry.lastPathComponent
                    eventsURL = entry.appendingPathComponent("events.jsonl")
                    priority = 2
                    guard FileManager.default.isReadableFile(atPath: eventsURL.path) else {
                        continue
                    }
                } else if values?.isRegularFile == true, entry.pathExtension == "jsonl" {
                    sessionID = entry.deletingPathExtension().lastPathComponent
                    eventsURL = entry
                    priority = 1
                } else {
                    continue
                }

                if candidates[sessionID]?.priority ?? 0 < priority {
                    candidates[sessionID] = Candidate(url: eventsURL, priority: priority)
                }
            }
        }

        return candidates.mapValues(\.url)
    }
}
