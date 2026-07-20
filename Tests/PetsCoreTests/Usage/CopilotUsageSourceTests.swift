import Foundation
import Testing
@testable import PetsCore

@Suite
struct CopilotUsageSourceTests {
    private let week = DateInterval(
        start: ISO8601DateFormatter().date(from: "2026-07-13T07:00:00Z")!,
        end: ISO8601DateFormatter().date(from: "2026-07-20T07:00:00Z")!
    )

    @Test
    func parserUsesShutdownTotalsAndOnlyTrailingLiveOutput() {
        let data = jsonLines([
            assistantLine("2026-07-14T08:00:00Z", output: 400),
            shutdownLine(
                "2026-07-14T08:01:00Z",
                input: 100,
                cacheRead: 200,
                cacheWrite: 300,
                output: 400
            ),
            assistantLine("2026-07-14T08:02:00Z", output: 50),
        ])

        #expect(CopilotUsageParser.tokens(in: data, interval: week) == 1_050)
    }

    @Test
    func parserDoesNotCountAnIdenticalShutdownEventTwice() {
        let shutdown = shutdownLine(
            "2026-07-14T08:01:00Z",
            input: 100,
            cacheRead: 200,
            cacheWrite: 300,
            output: 400
        )

        #expect(CopilotUsageParser.tokens(
            in: jsonLines([
                shutdown,
                assistantLine("2026-07-14T08:02:00Z", output: 50),
                shutdown,
            ]),
            interval: week
        ) == 1_050)
    }

    @Test
    func parserIgnoresMalformedAndOutOfPeriodEvents() {
        let data = jsonLines([
            "not-json",
            assistantLine("2026-07-13T06:59:00Z", output: 100),
            shutdownLine(
                "2026-07-20T07:00:00Z",
                input: 100,
                cacheRead: 200,
                cacheWrite: 300,
                output: 400
            ),
        ])

        #expect(CopilotUsageParser.tokens(in: data, interval: week) == 0)
    }

    @Test
    func sourceTracksVSCodeAndCLIOnceAcrossModernAndLegacyLayouts() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let duplicatedID = "11111111-1111-1111-1111-111111111111"
        try jsonLines([
            assistantLine("2026-07-14T08:00:00Z", output: 900),
        ]).write(to: root.appending(path: "\(duplicatedID).jsonl"))
        try writeSession(
            id: duplicatedID,
            root: root,
            lines: [shutdownLine(
                "2026-07-14T08:01:00Z",
                input: 25,
                cacheRead: 25,
                cacheWrite: 25,
                output: 25
            )]
        )

        try writeSession(
            id: "vscode-session",
            root: root,
            lines: [shutdownLine(
                "2026-07-14T09:00:00Z",
                input: 50,
                cacheRead: 50,
                cacheWrite: 50,
                output: 50
            )],
            clientName: "vscode"
        )
        try writeSession(
            id: "cli-session",
            root: root,
            lines: [shutdownLine(
                "2026-07-14T10:00:00Z",
                input: 75,
                cacheRead: 75,
                cacheWrite: 75,
                output: 75
            )],
            clientName: "cli"
        )

        let reading = try CopilotUsageSource(
            roots: [root],
            date: ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")!,
            calendar: utcCalendar()
        ).read()

        #expect(reading == PetUsageReading(
            providerID: "copilot",
            periodID: "2026-07-13",
            tokens: 600
        ))
    }

    @Test
    func currentWeekUsesMondayAndAStablePeriodID() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z"))

        let period = CopilotUsagePeriod(containing: date, calendar: calendar)

        #expect(period.id == "2026-07-13")
        #expect(period.interval.start == ISO8601DateFormatter().date(from: "2026-07-13T07:00:00Z"))
    }

    private func assistantLine(_ timestamp: String, output: Int64) -> String {
        "{\"type\":\"assistant.message\",\"timestamp\":\"\(timestamp)\",\"data\":{\"outputTokens\":\(output)}}"
    }

    private func shutdownLine(
        _ timestamp: String,
        input: Int64,
        cacheRead: Int64,
        cacheWrite: Int64,
        output: Int64
    ) -> String {
        "{\"type\":\"session.shutdown\",\"timestamp\":\"\(timestamp)\",\"data\":{\"tokenDetails\":{\"input\":{\"tokenCount\":\(input)},\"cache_read\":{\"tokenCount\":\(cacheRead)},\"cache_write\":{\"tokenCount\":\(cacheWrite)},\"output\":{\"tokenCount\":\(output)}}}}"
    }

    private func jsonLines(_ lines: [String]) -> Data {
        Data(lines.joined(separator: "\n").utf8)
    }

    private func writeSession(
        id: String,
        root: URL,
        lines: [String],
        clientName: String? = nil
    ) throws {
        let session = root.appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        try jsonLines(lines).write(to: session.appending(path: "events.jsonl"))
        if let clientName {
            try Data("client_name: \(clientName)\n".utf8)
                .write(to: session.appending(path: "workspace.yaml"))
        }
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
