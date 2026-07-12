import Testing
@testable import PetsCore

@Suite
struct PetSessionObservationCoordinatorTests {
    @Test
    func activationSuccessPreservesRecoverySuppressionUntilNextSessionObservation() {
        var coordinator = PetSessionObservationCoordinator()

        let initialBusyObservation = coordinator.observeSuccessfulSessions([session(status: .busy)])
        coordinator.recordError("Activation failed")
        coordinator.recordError(nil)
        let recoveredIdleObservation = coordinator.observeSuccessfulSessions([session(status: .idle)])

        let laterBusyObservation = coordinator.observeSuccessfulSessions([session(status: .busy)])
        let laterIdleObservation = coordinator.observeSuccessfulSessions([session(status: .idle)])

        #expect(!initialBusyObservation)
        #expect(!recoveredIdleObservation)
        #expect(!laterBusyObservation)
        #expect(laterIdleObservation)
    }

    @Test
    func replySuccessPreservesRecoverySuppressionUntilNextSessionObservation() {
        var coordinator = PetSessionObservationCoordinator()

        let initialBusyObservation = coordinator.observeSuccessfulSessions([session(status: .busy)])
        coordinator.recordError("Reply failed")
        coordinator.recordError(nil)
        let recoveredIdleObservation = coordinator.observeSuccessfulSessions([session(status: .idle)])

        let laterBusyObservation = coordinator.observeSuccessfulSessions([session(status: .busy)])
        let laterIdleObservation = coordinator.observeSuccessfulSessions([session(status: .idle)])

        #expect(!initialBusyObservation)
        #expect(!recoveredIdleObservation)
        #expect(!laterBusyObservation)
        #expect(laterIdleObservation)
    }

    private func session(status: HarnessSessionStatus) -> HarnessSession {
        HarnessSession(
            harnessID: "test-harness",
            harnessDisplayName: "Test Harness",
            sessionID: "chat",
            processID: 42,
            cwd: "/tmp",
            title: "Chat",
            kind: "interactive",
            entrypoint: "cli",
            status: status,
            updatedAt: nil,
            startedAt: nil
        )
    }
}
