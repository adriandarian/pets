import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetTrackedActivityRewardsTests {
    @Test
    func activityMustBeObservedContinuouslyBeforeItIsCredited() {
        var accumulator = PetTrackedActivityAccumulator()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(accumulator.observe(
            sessions: [session(providerID: "cursor", status: .busy)],
            eligibleProviderIDs: ["cursor"],
            at: start
        ).isEmpty)
        #expect(accumulator.observe(
            sessions: [session(providerID: "cursor", status: .busy)],
            eligibleProviderIDs: ["cursor"],
            at: start.addingTimeInterval(5)
        ) == [PetTrackedActivityIncrement(providerID: "cursor", seconds: 5)])
        #expect(accumulator.observe(
            sessions: [],
            eligibleProviderIDs: ["cursor"],
            at: start.addingTimeInterval(10)
        ).isEmpty)
    }

    @Test
    func accumulatorOnlyCreditsEnabledActivityProvidersAndClampsLongGaps() {
        var accumulator = PetTrackedActivityAccumulator()
        let start = Date(timeIntervalSince1970: 2_000)
        let sessions = [
            session(providerID: "cursor", status: .busy),
            session(providerID: "gemini", status: .waiting),
            session(providerID: "ollama", status: .idle),
        ]

        _ = accumulator.observe(
            sessions: sessions,
            eligibleProviderIDs: ["cursor", "gemini"],
            at: start
        )
        let increments = accumulator.observe(
            sessions: sessions,
            eligibleProviderIDs: ["cursor"],
            at: start.addingTimeInterval(60)
        )

        #expect(increments == [PetTrackedActivityIncrement(
            providerID: "cursor",
            seconds: Int64(PetTrackedActivityAccumulator.maximumCreditableGap)
        )])
    }

    private func session(
        providerID: String,
        status: HarnessSessionStatus
    ) -> HarnessSession {
        HarnessSession(
            harnessID: providerID,
            harnessDisplayName: providerID,
            sessionID: "session",
            processID: 42,
            cwd: "/tmp",
            title: providerID,
            kind: "local",
            entrypoint: providerID,
            status: status,
            updatedAt: nil,
            startedAt: nil
        )
    }
}
