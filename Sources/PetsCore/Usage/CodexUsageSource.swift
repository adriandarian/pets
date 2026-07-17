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
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()

        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(TokenEvent.self, from: Data(line)),
                  event.type == "event_msg",
                  event.payload.type == "token_count",
                  let tokens = event.payload.info?.totalTokenUsage.totalTokens,
                  let date = parseTimestamp(
                      event.timestamp,
                      fractionalFormatter: fractionalFormatter,
                      standardFormatter: standardFormatter
                  )
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

    private static func parseTimestamp(
        _ value: String,
        fractionalFormatter: ISO8601DateFormatter,
        standardFormatter: ISO8601DateFormatter
    ) -> Date? {
        fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}

public struct CodexUsageSource: PetUsageSource {
    public let id = "codex"
    public let displayName = "Codex"
    private let roots: [URL]
    private let date: Date
    private let calendar: Calendar
    private let cache: CodexUsageFileCache

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
        self.cache = CodexUsageFileCache()
    }

    public func read() throws -> PetUsageReading {
        let period = CodexUsagePeriod(containing: date, calendar: calendar)
        var total: Int64 = 0

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                guard let values = try? fileURL.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                ]),
                      values.isRegularFile == true,
                      let modificationDate = values.contentModificationDate,
                      modificationDate >= period.interval.start,
                      let fileSize = values.fileSize,
                      let fileTokens = cache.tokens(
                          for: fileURL,
                          signature: CodexUsageFileSignature(
                              fileSize: fileSize,
                              modificationDate: modificationDate
                          ),
                          periodID: period.id,
                          load: {
                              guard let data = try? Data(
                                  contentsOf: fileURL,
                                  options: .mappedIfSafe
                              ) else {
                                  return nil
                              }
                              return CodexUsageParser.tokens(
                                  in: data,
                                  interval: period.interval
                              )
                          }
                      )
                else {
                    continue
                }
                let result = total.addingReportingOverflow(fileTokens)
                total = result.overflow ? Int64.max : result.partialValue
            }
        }

        return PetUsageReading(providerID: id, periodID: period.id, tokens: total)
    }
}

private struct CodexUsageFileSignature: Equatable, Sendable {
    let fileSize: Int
    let modificationDate: Date
}

private final class CodexUsageFileCache: @unchecked Sendable {
    private struct Entry {
        let signature: CodexUsageFileSignature
        let periodID: String
        let tokens: Int64
    }

    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]

    func tokens(
        for url: URL,
        signature: CodexUsageFileSignature,
        periodID: String,
        load: () -> Int64?
    ) -> Int64? {
        if let cached = lock.withLock({ entries[url] }),
           cached.signature == signature,
           cached.periodID == periodID {
            return cached.tokens
        }

        guard let tokens = load() else { return nil }
        lock.withLock {
            entries[url] = Entry(
                signature: signature,
                periodID: periodID,
                tokens: tokens
            )
        }
        return tokens
    }
}
