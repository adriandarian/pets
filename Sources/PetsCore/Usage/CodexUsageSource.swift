import Foundation

public struct CodexUsagePeriod: Equatable, Sendable {
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

public enum CodexUsageParser {
    private struct TokenEvent: Decodable {
        struct Payload: Decodable {
            struct Info: Decodable {
                struct TokenUsage: Decodable {
                    let totalTokens: Int64

                    private enum CodingKeys: String, CodingKey {
                        case totalTokens = "total_tokens"
                    }
                }

                let totalTokenUsage: TokenUsage

                private enum CodingKeys: String, CodingKey {
                    case totalTokenUsage = "total_token_usage"
                }
            }

            let type: String
            let info: Info?
        }

        let timestamp: String
        let type: String
        let payload: Payload
    }

    public static func tokens(in data: Data, interval: DateInterval) -> Int64 {
        var baseline: (date: Date, tokens: Int64)?
        var maximumInside: Int64?

        for line in data.split(separator: 0x0A) {
            guard let event = try? JSONDecoder().decode(TokenEvent.self, from: Data(line)),
                  event.type == "event_msg",
                  event.payload.type == "token_count",
                  let tokens = event.payload.info?.totalTokenUsage.totalTokens,
                  let date = parseTimestamp(event.timestamp)
            else { continue }

            if date < interval.start {
                if baseline == nil || date > baseline!.date {
                    baseline = (date, max(0, tokens))
                }
            } else if date < interval.end {
                maximumInside = max(maximumInside ?? 0, max(0, tokens))
            }
        }

        guard let maximumInside else { return 0 }
        return max(0, maximumInside - (baseline?.tokens ?? 0))
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

public struct CodexUsageSource: PetUsageSource {
    public let id = "codex"
    public let displayName = "Codex"
    private let roots: [URL]
    private let date: Date
    private let calendar: Calendar

    public init(
        roots: [URL]? = nil,
        date: Date = Date(),
        calendar: Calendar = .current
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.roots = roots ?? [
            home.appendingPathComponent(".codex/sessions", isDirectory: true),
            home.appendingPathComponent(".codex/archived_sessions", isDirectory: true),
        ]
        self.date = date
        self.calendar = calendar
    }

    public func read() throws -> PetUsageReading {
        let period = CodexUsagePeriod(containing: date, calendar: calendar)
        var total: Int64 = 0

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { continue }
                let fileTokens = CodexUsageParser.tokens(in: data, interval: period.interval)
                let result = total.addingReportingOverflow(fileTokens)
                total = result.overflow ? Int64.max : result.partialValue
            }
        }

        return PetUsageReading(providerID: id, periodID: period.id, tokens: total)
    }
}
