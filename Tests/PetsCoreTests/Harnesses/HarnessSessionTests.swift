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
    }
}
