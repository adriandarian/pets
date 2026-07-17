import Foundation
import Testing
@testable import PetsCore

@Suite
struct CodexUsageSourceTests {
    private let week = DateInterval(
        start: ISO8601DateFormatter().date(from: "2026-07-13T07:00:00Z")!,
        end: ISO8601DateFormatter().date(from: "2026-07-20T07:00:00Z")!
    )

    @Test
    func parserUsesLatestCumulativeTotalInsteadOfSummingEvents() {
        let data = jsonLines([
            tokenLine("2026-07-13T08:00:00Z", total: nil),
            tokenLine("2026-07-13T08:01:00Z", total: 10_000),
            tokenLine("2026-07-13T08:02:00Z", total: 18_000),
        ])

        #expect(CodexUsageParser.tokens(in: data, interval: week) == 18_000)
    }

    @Test
    func parserSubtractsTheLastCumulativeValueBeforeThePeriod() {
        let data = jsonLines([
            tokenLine("2026-07-13T06:58:00Z", total: 40_000),
            tokenLine("2026-07-13T08:00:00Z", total: 50_000),
            tokenLine("2026-07-13T09:00:00Z", total: 75_000),
            tokenLine("2026-07-20T08:00:00Z", total: 90_000),
        ])

        #expect(CodexUsageParser.tokens(in: data, interval: week) == 35_000)
    }

    @Test
    func parserIgnoresMalformedAndUnrelatedEvents() {
        let data = jsonLines([
            "not-json",
            #"{"timestamp":"2026-07-13T08:00:00Z","type":"event_msg","payload":{"type":"task_started"}}"#,
            tokenLine("invalid-date", total: 40_000),
        ])

        #expect(CodexUsageParser.tokens(in: data, interval: week) == 0)
    }

    @Test
    func currentWeekUsesMondayAndAStablePeriodID() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z"))

        let period = CodexUsagePeriod(containing: date, calendar: calendar)

        #expect(period.id == "2026-07-13")
        #expect(period.interval.start == ISO8601DateFormatter().date(from: "2026-07-13T07:00:00Z"))
    }

    @Test
    func sourceSkipsFilesThatWereLastModifiedBeforeTheCurrentWeek() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "old-session.jsonl")
        try jsonLines([
            tokenLine("2026-07-13T08:00:00Z", total: 18_000),
        ]).write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: try #require(ISO8601DateFormatter().date(from: "2026-07-12T08:00:00Z"))],
            ofItemAtPath: file.path
        )

        let reading = try CodexUsageSource(
            roots: [root],
            date: try #require(ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")),
            calendar: utcCalendar()
        ).read()

        #expect(reading.tokens == 0)
    }

    @Test
    func sourceCachesTokensUntilFileMetadataChanges() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "active-session.jsonl")
        let initial = jsonLines([tokenLine("2026-07-13T08:00:00Z", total: 18_000)])
        let sameSizeReplacement = jsonLines([tokenLine("2026-07-13T08:00:00Z", total: 27_000)])
        #expect(initial.count == sameSizeReplacement.count)
        let modificationDate = try #require(
            ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")
        )
        try initial.write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: modificationDate],
            ofItemAtPath: file.path
        )

        let source = CodexUsageSource(
            roots: [root],
            date: modificationDate,
            calendar: utcCalendar()
        )
        #expect(try source.read().tokens == 18_000)

        try sameSizeReplacement.write(to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: modificationDate],
            ofItemAtPath: file.path
        )
        #expect(try source.read().tokens == 18_000)

        try jsonLines([
            tokenLine("2026-07-13T08:00:00Z", total: 27_000),
            tokenLine("2026-07-13T09:00:00Z", total: 35_000),
        ]).write(to: file)
        #expect(try source.read().tokens == 35_000)
    }

    private func tokenLine(_ timestamp: String, total: Int64?) -> String {
        let info: String
        if let total {
            info = "{\"total_token_usage\":{\"total_tokens\":\(total)}}"
        } else {
            info = "null"
        }
        return "{\"timestamp\":\"\(timestamp)\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":\(info)}}"
    }

    private func jsonLines(_ lines: [String]) -> Data {
        Data(lines.joined(separator: "\n").utf8)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
