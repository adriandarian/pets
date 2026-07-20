import Foundation
import Testing
@testable import PetsCore

@Suite
struct MultiProviderHarnessTests {
    @Test
    func scanCombinesProvidersAndSortsByLatestActivity() throws {
        let older = session(harnessID: "claude", id: "one", updatedAt: 10)
        let newer = session(harnessID: "codex", id: "two", updatedAt: 20)
        let harness = MultiProviderHarness(harnesses: [
            StubHarness(id: "claude", session: older),
            StubHarness(id: "codex", session: newer),
        ])

        let sessions = try harness.scan()

        #expect(sessions.map(\.id) == [newer.id, older.id])
    }

    @Test
    func activationRoutesToTheSessionProvider() throws {
        let target = session(harnessID: "codex", id: "two", updatedAt: 20)
        let harness = MultiProviderHarness(harnesses: [
            StubHarness(id: "claude", session: session(harnessID: "claude", id: "one", updatedAt: 10)),
            StubHarness(id: "codex", session: target, appName: "Codex"),
        ])

        #expect(try harness.activate(target) == .activatedApp(appName: "Codex"))
    }

    @Test
    func oneUnavailableProviderDoesNotHideOtherProviderSessions() throws {
        let codex = session(harnessID: "codex", id: "available", updatedAt: 20)
        let harness = MultiProviderHarness(harnesses: [
            FailingHarness(id: "claude"),
            StubHarness(id: "codex", session: codex),
        ])

        #expect(try harness.scan() == [codex])
    }

    private func session(harnessID: String, id: String, updatedAt: TimeInterval) -> HarnessSession {
        HarnessSession(
            harnessID: harnessID,
            harnessDisplayName: harnessID,
            sessionID: id,
            processID: nil,
            cwd: "/tmp",
            title: id,
            kind: "test",
            entrypoint: "test",
            status: .idle,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            startedAt: nil
        )
    }
}

private struct StubHarness: PetHarness {
    let id: String
    let displayName: String
    let session: HarnessSession
    let appName: String

    init(id: String, session: HarnessSession, appName: String = "Stub") {
        self.id = id
        self.displayName = id
        self.session = session
        self.appName = appName
    }

    func scan() throws -> [HarnessSession] {
        [session]
    }

    func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        .activatedApp(appName: appName)
    }

    func sendReply(_ message: String, to session: HarnessSession) throws {}
}

private struct FailingHarness: PetHarness {
    let id: String
    let displayName: String

    init(id: String) {
        self.id = id
        self.displayName = id
    }

    func scan() throws -> [HarnessSession] {
        throw PetHarnessError.activationFailed(provider: id)
    }

    func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        throw PetHarnessError.activationFailed(provider: id)
    }

    func sendReply(_ message: String, to session: HarnessSession) throws {
        throw PetHarnessError.replyUnsupported(provider: id)
    }
}
