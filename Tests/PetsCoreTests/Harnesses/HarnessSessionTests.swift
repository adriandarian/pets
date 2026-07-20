import Foundation
import Testing
@testable import PetsCore

@Suite
struct HarnessSessionTests {
    @Test
    func statusExposesAnimationSemanticsWithoutHarnessNames() {
        #expect(HarnessSessionStatus.busy.isRunning)
        #expect(!HarnessSessionStatus.waiting.isRunning)
        #expect(!HarnessSessionStatus.idle.isRunning)
        #expect(!HarnessSessionStatus.unknown.isRunning)

        #expect(HarnessSessionStatus.busy.usesContinuousSpriteMotion)
        #expect(HarnessSessionStatus.waiting.usesContinuousSpriteMotion)
        #expect(!HarnessSessionStatus.idle.usesContinuousSpriteMotion)
        #expect(!HarnessSessionStatus.unknown.usesContinuousSpriteMotion)
    }

    @Test
    func sessionCarriesHarnessIdentityAndReplyCapability() {
        let session = HarnessSession(
            harnessID: "claude",
            harnessDisplayName: "Claude Code",
            sessionID: "session-1",
            processID: 42,
            cwd: "/tmp/project",
            title: "Fix build",
            chatPreview: "Compiler failed",
            dismissalToken: "prompt-token",
            kind: "interactive",
            entrypoint: "terminal",
            status: .waiting,
            replyTarget: .terminal(tty: "ttys001"),
            updatedAt: Date(timeIntervalSince1970: 10),
            startedAt: Date(timeIntervalSince1970: 1)
        )

        #expect(session.id == "claude:session-1")
        #expect(session.harnessID == "claude")
        #expect(session.supportsReply)
        #expect(session.status == .waiting)
        #expect(session.sourceDisplayName == "Claude Code")
    }

    @Test
    func codexAndCopilotSessionsExposeTheirSpecificEntrypoints() {
        let codex = HarnessSession(
            harnessID: PetTrackingProvider.codex.rawValue,
            harnessDisplayName: "Codex",
            sessionID: "codex-session",
            processID: nil,
            cwd: "/tmp",
            title: "Task",
            kind: "task",
            entrypoint: "Codex CLI",
            status: .busy,
            updatedAt: nil,
            startedAt: nil
        )
        let copilot = HarnessSession(
            harnessID: PetTrackingProvider.githubCopilot.rawValue,
            harnessDisplayName: "GitHub Copilot",
            sessionID: "copilot-session",
            processID: nil,
            cwd: "/tmp",
            title: "Chat",
            kind: "chat",
            entrypoint: "Copilot chat",
            status: .idle,
            updatedAt: nil,
            startedAt: nil
        )

        #expect(codex.sourceDisplayName == "Codex CLI")
        #expect(copilot.sourceDisplayName == "Copilot chat")
    }
}
