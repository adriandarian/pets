import Testing
@testable import PetsCore

@Suite
struct PetSessionTransitionDetectorTests {
    @Test
    func initialSnapshotAndNewIdleSessionsDoNotComplete() {
        var detector = PetSessionTransitionDetector()

        let initialObservation = detector.observe([session(id: "existing", status: .idle)])
        let newIdleObservation = detector.observe([
            session(id: "existing", status: .idle),
            session(id: "new", status: .idle),
        ])

        #expect(!initialObservation)
        #expect(!newIdleObservation)
    }

    @Test
    func everyObservedNonIdleToIdleTransitionCompletes() {
        for status in [HarnessSessionStatus.busy, .waiting, .unknown] {
            var detector = PetSessionTransitionDetector()
            let initialObservation = detector.observe([session(id: "chat", status: status)])
            let idleObservation = detector.observe([session(id: "chat", status: .idle)])

            #expect(!initialObservation)
            #expect(idleObservation)
        }
    }

    @Test
    func unchangedIdleAndIdleToBusyDoNotComplete() {
        var unchangedDetector = PetSessionTransitionDetector()
        let initialIdleObservation = unchangedDetector.observe([session(id: "chat", status: .idle)])
        let unchangedIdleObservation = unchangedDetector.observe([session(id: "chat", status: .idle)])

        var busyDetector = PetSessionTransitionDetector()
        let busyDetectorInitialObservation = busyDetector.observe([session(id: "chat", status: .idle)])
        let busyObservation = busyDetector.observe([session(id: "chat", status: .busy)])

        #expect(!initialIdleObservation)
        #expect(!unchangedIdleObservation)
        #expect(!busyDetectorInitialObservation)
        #expect(!busyObservation)
    }

    @Test
    func sessionIdentityIncludesHarnessID() {
        var detector = PetSessionTransitionDetector()

        let claudeObservation = detector.observe([
            session(harnessID: "claude", id: "shared", status: .busy),
        ])
        let codexObservation = detector.observe([
            session(harnessID: "codex", id: "shared", status: .idle),
        ])

        #expect(!claudeObservation)
        #expect(!codexObservation)
    }

    @Test
    func multipleTransitionsProduceOneCompletionSignal() {
        var detector = PetSessionTransitionDetector()

        let initialObservation = detector.observe([
            session(id: "one", status: .busy),
            session(id: "two", status: .waiting),
        ])
        let idleObservation = detector.observe([
            session(id: "one", status: .idle),
            session(id: "two", status: .idle),
        ])

        #expect(!initialObservation)
        #expect(idleObservation)
    }

    @Test
    func completedHarnessIDsIdentifyEveryProviderThatCompleted() {
        var detector = PetSessionTransitionDetector()
        _ = detector.observeCompletedHarnessIDs([
            session(harnessID: "claude", id: "one", status: .busy),
            session(harnessID: "codex", id: "two", status: .waiting),
            session(harnessID: "copilot", id: "three", status: .busy),
        ])

        let completed = detector.observeCompletedHarnessIDs([
            session(harnessID: "claude", id: "one", status: .idle),
            session(harnessID: "codex", id: "two", status: .idle),
            session(harnessID: "copilot", id: "three", status: .busy),
        ])

        #expect(completed == ["claude", "codex"])
    }

    @Test
    func suppressedCompletionAdvancesSnapshotWithoutReplayingTransition() {
        var detector = PetSessionTransitionDetector()

        let initialObservation = detector.observe([session(id: "chat", status: .busy)])
        let suppressedIdleObservation = detector.observe(
            [session(id: "chat", status: .idle)],
            suppressCompletion: true
        )
        let unchangedIdleObservation = detector.observe([session(id: "chat", status: .idle)])

        #expect(!initialObservation)
        #expect(!suppressedIdleObservation)
        #expect(!unchangedIdleObservation)
    }

    private func session(
        harnessID: String = "test-harness",
        id: String,
        status: HarnessSessionStatus
    ) -> HarnessSession {
        HarnessSession(
            harnessID: harnessID,
            harnessDisplayName: "Test Harness",
            sessionID: id,
            processID: 42,
            cwd: "/tmp",
            title: id,
            kind: "interactive",
            entrypoint: "cli",
            status: status,
            updatedAt: nil,
            startedAt: nil
        )
    }
}
