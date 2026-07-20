import Foundation

public struct ClaudeCodeUsagePeriod: Equatable, Sendable {
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

public struct ClaudeCodeUsageSample: Equatable, Sendable {
    public let requestID: String
    public let timestamp: Date
    public let tokens: Int64

    public init(requestID: String, timestamp: Date, tokens: Int64) {
        self.requestID = requestID
        self.timestamp = timestamp
        self.tokens = max(0, tokens)
    }
}

public enum ClaudeCodeUsageParser {
    private struct TranscriptEntry: Decodable {
        struct Message: Decodable {
            struct Usage: Decodable {
                let inputTokens: Int64?
                let cacheCreationInputTokens: Int64?
                let cacheReadInputTokens: Int64?
                let outputTokens: Int64?

                private enum CodingKeys: String, CodingKey {
                    case inputTokens = "input_tokens"
                    case cacheCreationInputTokens = "cache_creation_input_tokens"
                    case cacheReadInputTokens = "cache_read_input_tokens"
                    case outputTokens = "output_tokens"
                }

                var totalTokens: Int64 {
                    [
                        inputTokens,
                        cacheCreationInputTokens,
                        cacheReadInputTokens,
                        outputTokens,
                    ].reduce(into: 0) { total, value in
                        guard let value else { return }
                        total = ClaudeCodeUsageParser.addingClamped(total, max(0, value))
                    }
                }
            }

            let id: String?
            let usage: Usage?
        }

        let type: String
        let uuid: String?
        let requestID: String?
        let timestamp: String
        let message: Message?

        private enum CodingKeys: String, CodingKey {
            case type
            case uuid
            case requestID = "requestId"
            case timestamp
            case message
        }
    }

    public static func samples(in data: Data) -> [ClaudeCodeUsageSample] {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        var samplesByRequest: [String: ClaudeCodeUsageSample] = [:]

        for line in data.split(separator: 0x0A) {
            guard let entry = try? decoder.decode(TranscriptEntry.self, from: Data(line)),
                  entry.type == "assistant",
                  let usage = entry.message?.usage,
                  let requestID = firstNonempty(entry.requestID, entry.message?.id, entry.uuid),
                  let timestamp = parseTimestamp(
                      entry.timestamp,
                      fractionalFormatter: fractionalFormatter,
                      standardFormatter: standardFormatter
                  ),
                  usage.totalTokens > 0
            else { continue }

            let sample = ClaudeCodeUsageSample(
                requestID: requestID,
                timestamp: timestamp,
                tokens: usage.totalTokens
            )
            samplesByRequest[requestID] = merged(samplesByRequest[requestID], with: sample)
        }

        return samplesByRequest.values.sorted { $0.requestID < $1.requestID }
    }

    fileprivate static func merged(
        _ existing: ClaudeCodeUsageSample?,
        with sample: ClaudeCodeUsageSample
    ) -> ClaudeCodeUsageSample {
        guard let existing else { return sample }
        return ClaudeCodeUsageSample(
            requestID: sample.requestID,
            timestamp: min(existing.timestamp, sample.timestamp),
            tokens: max(existing.tokens, sample.tokens)
        )
    }

    private static func firstNonempty(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.isEmpty {
                return value
            }
        }
        return nil
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

public struct ClaudeCodeUsageSource: PetUsageSource {
    public let id = "claude"
    public let displayName = "Claude"
    private let roots: [URL]
    private let date: Date
    private let calendar: Calendar
    private let cache: ClaudeCodeUsageFileCache

    public init(
        roots: [URL]? = nil,
        date: Date = Date(),
        calendar: Calendar = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let configurationDirectory: URL
        if let configuredPath = environment["CLAUDE_CONFIG_DIR"], !configuredPath.isEmpty {
            configurationDirectory = URL(fileURLWithPath: configuredPath, isDirectory: true)
        } else {
            configurationDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude", isDirectory: true)
        }
        self.roots = roots ?? [
            configurationDirectory.appendingPathComponent("projects", isDirectory: true),
        ]
        self.date = date
        self.calendar = calendar
        self.cache = ClaudeCodeUsageFileCache()
    }

    public func read() throws -> PetUsageReading {
        let period = ClaudeCodeUsagePeriod(containing: date, calendar: calendar)
        var samplesByRequest: [String: ClaudeCodeUsageSample] = [:]

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
                      let samples = cache.samples(
                          for: fileURL,
                          signature: ClaudeCodeUsageFileSignature(
                              fileSize: fileSize,
                              modificationDate: modificationDate
                          ),
                          load: {
                              guard let data = try? Data(
                                  contentsOf: fileURL,
                                  options: .mappedIfSafe
                              ) else {
                                  return nil
                              }
                              return ClaudeCodeUsageParser.samples(in: data)
                          }
                      )
                else { continue }

                for sample in samples {
                    samplesByRequest[sample.requestID] = ClaudeCodeUsageParser.merged(
                        samplesByRequest[sample.requestID],
                        with: sample
                    )
                }
            }
        }

        var total: Int64 = 0
        for sample in samplesByRequest.values
        where sample.timestamp >= period.interval.start && sample.timestamp < period.interval.end {
            let result = total.addingReportingOverflow(sample.tokens)
            total = result.overflow ? Int64.max : result.partialValue
        }

        return PetUsageReading(providerID: id, periodID: period.id, tokens: total)
    }
}

private struct ClaudeCodeUsageFileSignature: Equatable, Sendable {
    let fileSize: Int
    let modificationDate: Date
}

private final class ClaudeCodeUsageFileCache: @unchecked Sendable {
    private struct Entry {
        let signature: ClaudeCodeUsageFileSignature
        let samples: [ClaudeCodeUsageSample]
    }

    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]

    func samples(
        for url: URL,
        signature: ClaudeCodeUsageFileSignature,
        load: () -> [ClaudeCodeUsageSample]?
    ) -> [ClaudeCodeUsageSample]? {
        if let cached = lock.withLock({ entries[url] }), cached.signature == signature {
            return cached.samples
        }

        guard let samples = load() else { return nil }
        lock.withLock {
            entries[url] = Entry(signature: signature, samples: samples)
        }
        return samples
    }
}
