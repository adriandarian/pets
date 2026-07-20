import Testing
@testable import PetsCore

@Suite
struct PetSessionRoutingTests {
    @Test
    func eachPetOnlyReceivesSessionsFromItsAssignedProviders() {
        let sessions = [
            session(provider: .claudeCode, id: "claude"),
            session(provider: .codex, id: "codex"),
            session(provider: .githubCopilot, id: "copilot"),
        ]
        var first = PetInstance.defaultInstance()
        first.trackingProviders = [.claudeCode, .codex]
        var second = PetInstance.defaultInstance()
        second.trackingProviders = [.githubCopilot]
        var unassigned = PetInstance.defaultInstance()
        unassigned.trackingProviders = []

        #expect(PetSessionRouting.sessions(sessions, trackedBy: first).map(\.sessionID) == [
            "claude", "codex",
        ])
        #expect(PetSessionRouting.sessions(sessions, trackedBy: second).map(\.sessionID) == [
            "copilot",
        ])
        #expect(PetSessionRouting.sessions(sessions, trackedBy: unassigned).isEmpty)
    }

    @Test
    func statusPriorityIsComputedFromOnlyTheRoutedSessions() {
        #expect(PetSessionRouting.dominantStatus(in: []) == .unknown)
        #expect(PetSessionRouting.dominantStatus(in: [
            session(provider: .codex, id: "idle", status: .idle),
        ]) == .idle)
        #expect(PetSessionRouting.dominantStatus(in: [
            session(provider: .codex, id: "busy", status: .busy),
            session(provider: .githubCopilot, id: "waiting", status: .waiting),
        ]) == .waiting)
    }

    @Test
    func completionReactionOnlyReachesPetsTrackingACompletedProvider() {
        var codexPet = PetInstance.defaultInstance()
        codexPet.trackingProviders = [.codex]
        var claudePet = PetInstance.defaultInstance()
        claudePet.trackingProviders = [.claudeCode]
        var unassigned = PetInstance.defaultInstance()
        unassigned.trackingProviders = []

        #expect(PetSessionRouting.reaction(
            .completion,
            completedProviderIDs: [PetTrackingProvider.codex.rawValue],
            for: codexPet
        ) == .completion)
        #expect(PetSessionRouting.reaction(
            .completion,
            completedProviderIDs: [PetTrackingProvider.codex.rawValue],
            for: claudePet
        ) == nil)
        #expect(PetSessionRouting.reaction(
            .completion,
            completedProviderIDs: [PetTrackingProvider.codex.rawValue],
            for: unassigned
        ) == nil)
        #expect(PetSessionRouting.reaction(
            .error,
            completedProviderIDs: [],
            for: unassigned
        ) == .error)
    }

    private func session(
        provider: PetTrackingProvider,
        id: String,
        status: HarnessSessionStatus = .idle
    ) -> HarnessSession {
        HarnessSession(
            harnessID: provider.rawValue,
            harnessDisplayName: provider.displayName,
            sessionID: id,
            processID: nil,
            cwd: "/tmp",
            title: id,
            kind: "test",
            entrypoint: "test",
            status: status,
            updatedAt: nil,
            startedAt: nil
        )
    }
}
