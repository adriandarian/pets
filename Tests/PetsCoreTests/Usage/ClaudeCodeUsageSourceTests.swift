import Foundation
import Testing
@testable import PetsCore

@Suite
struct ClaudeCodeUsageSourceTests {
    @Test
    func parserDeduplicatesRepeatedRowsAndKeepsMaximumRequestUsage() {
        let data = jsonLines([
            assistantLine(
                timestamp: "2026-07-14T08:00:00Z",
                requestID: "request-1",
                messageID: "message-1",
                input: 100,
                cacheCreation: 200,
                cacheRead: 300,
                output: 400
            ),
            assistantLine(
                timestamp: "2026-07-14T08:00:01Z",
                requestID: "request-1",
                messageID: "message-1",
                input: 100,
                cacheCreation: 200,
                cacheRead: 300,
                output: 450
            ),
            assistantLine(
                timestamp: "2026-07-14T08:00:02Z",
                requestID: "request-1",
                messageID: "message-1",
                input: 100,
                cacheCreation: 200,
                cacheRead: 300,
                output: 450
            ),
        ])

        let samples = ClaudeCodeUsageParser.samples(in: data)

        #expect(samples == [ClaudeCodeUsageSample(
            requestID: "request-1",
            timestamp: ISO8601DateFormatter().date(from: "2026-07-14T08:00:00Z")!,
            tokens: 1_050
        )])
    }

    @Test
    func parserFallsBackToMessageIDAndIgnoresMalformedUsage() {
        let data = jsonLines([
            "not-json",
            #"{"type":"user","timestamp":"2026-07-14T08:00:00Z"}"#,
            assistantLine(
                timestamp: "2026-07-14T08:01:00Z",
                requestID: nil,
                messageID: "message-2",
                input: 10,
                cacheCreation: 20,
                cacheRead: 30,
                output: 40
            ),
        ])

        #expect(ClaudeCodeUsageParser.samples(in: data) == [ClaudeCodeUsageSample(
            requestID: "message-2",
            timestamp: ISO8601DateFormatter().date(from: "2026-07-14T08:01:00Z")!,
            tokens: 100
        )])
    }

    @Test
    func sourceCountsMainAndSubagentRequestsOnceAcrossCopiedTranscripts() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "project", directoryHint: .isDirectory)
        let session = project.appending(path: "session", directoryHint: .isDirectory)
        let subagents = session.appending(path: "subagents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: subagents, withIntermediateDirectories: true)

        let shared = assistantLine(
            timestamp: "2026-07-14T08:00:00Z",
            requestID: "shared-request",
            messageID: "shared-message",
            input: 25,
            cacheCreation: 25,
            cacheRead: 25,
            output: 25
        )
        let mainOnly = assistantLine(
            timestamp: "2026-07-14T09:00:00Z",
            requestID: "main-request",
            messageID: "main-message",
            input: 50,
            cacheCreation: 50,
            cacheRead: 50,
            output: 50
        )
        let subagentOnly = assistantLine(
            timestamp: "2026-07-14T10:00:00Z",
            requestID: "subagent-request",
            messageID: "subagent-message",
            input: 75,
            cacheCreation: 75,
            cacheRead: 75,
            output: 75
        )
        try jsonLines([shared, mainOnly])
            .write(to: project.appending(path: "session.jsonl"))
        try jsonLines([shared, subagentOnly])
            .write(to: subagents.appending(path: "agent-copy.jsonl"))
        try jsonLines([mainOnly])
            .write(to: project.appending(path: "forked-session.jsonl"))

        let reading = try ClaudeCodeUsageSource(
            roots: [root],
            date: ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")!,
            calendar: utcCalendar()
        ).read()

        #expect(reading == PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 600
        ))
    }

    @Test
    func sourceUsesTheEarliestTimestampWhenDuplicatesCrossAWeekBoundary() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        try jsonLines([
            assistantLine(
                timestamp: "2026-07-13T06:59:59Z",
                requestID: "boundary-request",
                messageID: "boundary-message",
                input: 25,
                cacheCreation: 25,
                cacheRead: 25,
                output: 25
            ),
            assistantLine(
                timestamp: "2026-07-13T07:00:01Z",
                requestID: "boundary-request",
                messageID: "boundary-message",
                input: 25,
                cacheCreation: 25,
                cacheRead: 25,
                output: 25
            ),
        ]).write(to: project.appending(path: "session.jsonl"))

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let reading = try ClaudeCodeUsageSource(
            roots: [root],
            date: ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")!,
            calendar: calendar
        ).read()

        #expect(reading.tokens == 0)
    }

    @Test
    func sourceSkipsTranscriptsLastModifiedBeforeTheCurrentWeek() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let transcript = project.appending(path: "old-session.jsonl")

        try jsonLines([
            assistantLine(
                timestamp: "2026-07-14T08:00:00Z",
                requestID: "request-in-old-file",
                messageID: "message-in-old-file",
                input: 25,
                cacheCreation: 25,
                cacheRead: 25,
                output: 25
            ),
        ]).write(to: transcript)
        try FileManager.default.setAttributes(
            [.modificationDate: try #require(
                ISO8601DateFormatter().date(from: "2026-07-12T08:00:00Z")
            )],
            ofItemAtPath: transcript.path
        )

        let reading = try ClaudeCodeUsageSource(
            roots: [root],
            date: ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z")!,
            calendar: utcCalendar()
        ).read()

        #expect(reading.tokens == 0)
    }

    @Test
    func currentWeekUsesMondayAndAStablePeriodID() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-16T18:00:00Z"))

        let period = ClaudeCodeUsagePeriod(containing: date, calendar: calendar)

        #expect(period.id == "2026-07-13")
        #expect(period.interval.start == ISO8601DateFormatter().date(from: "2026-07-13T07:00:00Z"))
    }

    private func assistantLine(
        timestamp: String,
        requestID: String?,
        messageID: String,
        input: Int64,
        cacheCreation: Int64,
        cacheRead: Int64,
        output: Int64
    ) -> String {
        let requestField = requestID.map { "\"requestId\":\"\($0)\"," } ?? ""
        return "{\"type\":\"assistant\",\"uuid\":\"entry-\(messageID)\",\"timestamp\":\"\(timestamp)\",\(requestField)\"message\":{\"id\":\"\(messageID)\",\"usage\":{\"input_tokens\":\(input),\"cache_creation_input_tokens\":\(cacheCreation),\"cache_read_input_tokens\":\(cacheRead),\"output_tokens\":\(output)}}}"
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
