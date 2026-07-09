import CoreGraphics
import Foundation
import Testing
@testable import PetsCore

@Suite
struct ClaudeSessionScannerTests {
    @Test
    func overlayPlacementFlipsChatsAwayFromScreenEdges() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let offscreenLeftFrame = CGRect(x: -360, y: 42, width: 500, height: 360)
        let centeredFrame = CGRect(x: 470, y: 42, width: 500, height: 360)
        let offscreenRightFrame = CGRect(x: 1300, y: 42, width: 500, height: 360)

        #expect(
            PetOverlayHorizontalPlacement.preferred(
                for: offscreenLeftFrame,
                in: screenFrame,
                current: .trailing
            ) == .leading
        )
        #expect(
            PetOverlayHorizontalPlacement.preferred(
                for: centeredFrame,
                in: screenFrame,
                current: .leading
            ) == .leading
        )
        #expect(
            PetOverlayHorizontalPlacement.preferred(
                for: offscreenRightFrame,
                in: screenFrame,
                current: .leading
            ) == .trailing
        )
    }

    @Test
    func overlayPanelFrameIsKeptInsideVisibleScreenAfterPlacementChange() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let offscreenLeftFrame = CGRect(x: -360, y: 42, width: 500, height: 360)

        let adjustedFrame = PetOverlayHorizontalPlacement.adjustedPanelFrame(
            offscreenLeftFrame,
            in: screenFrame
        )

        #expect(adjustedFrame.minX == screenFrame.minX)
    }

    @Test
    func busyStatusIsMarkedAsRunningForAnimatedUI() {
        #expect(HarnessSessionStatus.busy.isRunning)
        #expect(!HarnessSessionStatus.waiting.isRunning)
        #expect(!HarnessSessionStatus.idle.isRunning)
        #expect(!HarnessSessionStatus.unknown.isRunning)
    }

    @Test
    func onlyActiveStatusesRequestContinuousSpriteMotion() {
        #expect(HarnessSessionStatus.busy.usesContinuousSpriteMotion)
        #expect(HarnessSessionStatus.waiting.usesContinuousSpriteMotion)
        #expect(!HarnessSessionStatus.idle.usesContinuousSpriteMotion)
        #expect(!HarnessSessionStatus.unknown.usesContinuousSpriteMotion)
    }

    @Test
    func excitedHoverRequestsSpriteMotionForIdlePetOnlyWhileHovered() {
        #expect(PetHoverExcitement.usesContinuousSpriteMotion(status: .idle, isHovered: true))
        #expect(!PetHoverExcitement.usesContinuousSpriteMotion(status: .idle, isHovered: false))
    }

    @Test
    func excitedHoverTransformKeepsScaleFixedWhileAddingLift() {
        #expect(PetHoverExcitement.scale(isHovered: true) == PetHoverExcitement.scale(isHovered: false))
        #expect(PetHoverExcitement.verticalOffset(isHovered: true) < PetHoverExcitement.verticalOffset(isHovered: false))
        #expect(PetHoverExcitement.scale(isHovered: true) == 1.0)
    }

    @Test
    func cuteCloudPetIsDefaultWhileClassicPetStaysAvailable() {
        #expect(PetCatalog.defaultPetID == .cuteCloud)
        #expect(PetCatalog.builtInPetIDs.first == .cuteCloud)
        #expect(PetCatalog.builtInPetIDs.contains(.classicCloud))
        #expect(PetCatalog.builtInPetIDs.contains(.helperCloud))
        #expect(PetCatalog.builtInPetIDs.contains(.sleepCloud))
        #expect(PetCatalog.builtInPetIDs.contains(.focusCloud))
        #expect(PetCatalog.displayName(for: .classicCloud) == "Classic Cloud")
        #expect(PetCatalog.renderFamily(for: .classicCloud) == .cloud)
    }

    @Test
    func builtInPetsAreGroupedIntoPickerCategories() {
        let categories = PetCatalog.builtInCategories

        #expect(categories.first?.id == "cloud-pets")
        #expect(categories.first?.displayName == "Cloud Pets")
        #expect(categories.first?.petIDs == [
            .cuteCloud,
            .classicCloud,
            .helperCloud,
            .sleepCloud,
            .focusCloud
        ])
        #expect(categories.count >= 4)

        let categorizedPetIDs = categories.flatMap(\.petIDs)
        #expect(categorizedPetIDs == PetCatalog.builtInPetIDs)
        #expect(Set(categorizedPetIDs).count == PetCatalog.builtInPetIDs.count)

        let nonCloudCategories = categories.dropFirst()
        #expect(nonCloudCategories.allSatisfy { !$0.petIDs.isEmpty })
        #expect(nonCloudCategories.allSatisfy { category in
            category.petIDs.allSatisfy { !categories[0].petIDs.contains($0) }
        })
    }

    @Test
    func customPetIDsPreserveStableUserProvidedName() throws {
        let customID = PetID.custom("tiny-bot")

        #expect(customID.rawValue == "custom:tiny-bot")
        #expect(PetID(rawValue: customID.rawValue) == customID)
    }

    @Test
    func petPixelationClampsToSpriteCapability() {
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .cuteCloud) == .medium)
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .classicCloud) == .chunky)
        #expect(PetCatalog.pixelation(.medium, allowedFor: PetID.custom("future")) == .off)
    }

    @Test
    func petPixelationRawValuesFallBackToOff() {
        #expect(PetSpritePixelation(rawValue: "medium") == .medium)
        #expect(PetSpritePixelation.persisted(rawValue: "invalid") == .off)
        #expect(PetSpritePixelation.persisted(rawValue: nil) == .off)
    }

    @Test
    func sessionContextLineCountClampsToSupportedRange() {
        #expect(PetSessionContextLineCount.defaultValue == 2)
        #expect(PetSessionContextLineCount.clamped(0) == 1)
        #expect(PetSessionContextLineCount.clamped(3) == 3)
        #expect(PetSessionContextLineCount.clamped(9) == 4)
        #expect(Array(PetSessionContextLineCount.supportedRange) == [1, 2, 3, 4])
    }

    @Test
    func unreadChatCountIncludesWaitingSessionsOnly() {
        let sessions = [
            makeSession(sessionId: "waiting-1", displayStatus: .waiting),
            makeSession(sessionId: "busy-1", displayStatus: .busy),
            makeSession(sessionId: "idle-1", displayStatus: .idle),
            makeSession(sessionId: "waiting-2", displayStatus: .waiting),
            makeSession(sessionId: "unknown-1", displayStatus: .unknown)
        ]

        #expect(ClaudeSession.unreadChatCount(in: sessions) == 2)
    }

    @Test
    func collapsedChatCountIncludesCompletedSessions() {
        let sessions = [
            makeSession(sessionId: "complete-session", displayStatus: .idle)
        ]

        #expect(ClaudeSession.collapsedChatCount(in: sessions) == 1)
    }

    @Test
    func overflowBadgeLabelUsesPlusPrefix() {
        #expect(PetBadgeLabel.overflowCount(15) == "+15")
    }

    @Test
    func overflowBadgeCountsRowsNotYetVisibleBelowViewport() {
        #expect(
            PetOverflowBadgeVisibility.remainingBelowViewport(
                rowMinYValues: [0, 80, 160, 260],
                viewportHeight: 250
            ) == 1
        )
        #expect(
            PetOverflowBadgeVisibility.remainingBelowViewport(
                rowMinYValues: [-80, 0, 80, 160],
                viewportHeight: 250
            ) == 0
        )
    }

    @Test
    func replyControlPlacementDoesNotMoveTextWhenReplyButtonAppears() {
        #expect(
            PetReplyControlPlacement.titleTrailingPadding(replyButtonVisible: true)
                == PetReplyControlPlacement.titleTrailingPadding(replyButtonVisible: false)
        )
    }

    @Test
    func dismissedSessionsAreRemovedFromVisibleSessionListOnlyForCurrentPrompt() {
        let sessions = [
            makeSession(sessionId: "first", displayStatus: .waiting, dismissalToken: "first-prompt"),
            makeSession(sessionId: "second", displayStatus: .busy, dismissalToken: "old-prompt"),
            makeSession(sessionId: "third", displayStatus: .idle, dismissalToken: "third-prompt")
        ].map { $0.harnessSession() }

        let visibleSessions = PetDismissedSessionFilter.visibleSessions(
            sessions,
            dismissedSessions: [PetDismissedSession(session: sessions[1])]
        )

        #expect(visibleSessions.map(\.sessionID) == ["first", "third"])
    }

    @Test
    func dismissedSessionReturnsWhenItsPromptTokenChanges() {
        let dismissedSession = makeSession(
            sessionId: "same-session",
            displayStatus: .idle,
            dismissalToken: "old-prompt"
        ).harnessSession()
        let refreshedSession = makeSession(
            sessionId: "same-session",
            displayStatus: .busy,
            dismissalToken: "new-prompt"
        ).harnessSession()

        let visibleSessions = PetDismissedSessionFilter.visibleSessions(
            [refreshedSession],
            dismissedSessions: [PetDismissedSession(session: dismissedSession)]
        )

        #expect(visibleSessions.map(\.sessionID) == ["same-session"])
    }

    @Test
    func untitledSessionsWithoutChatPreviewAreHiddenFromVisibleSessionList() {
        let sessions = [
            makeSession(sessionId: "empty", title: "Untitled chat", chatPreview: nil),
            makeSession(sessionId: "titled", title: "Review failing CI", chatPreview: nil),
            makeSession(sessionId: "content", title: "Untitled chat", chatPreview: "Please check this build")
        ].map { $0.harnessSession() }

        let visibleSessions = PetDismissedSessionFilter.visibleSessions(
            sessions,
            dismissedSessions: []
        )

        #expect(visibleSessions.map(\.sessionID) == ["titled", "content"])
    }

    @Test
    func scannerKeepsOnlyLiveClaudeSessionsAndSortsNewestFirst() throws {
        let root = try TemporaryDirectory()
        let sessionsDirectory = root.url.appending(path: ".claude/sessions", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "101.json",
            in: sessionsDirectory,
            pid: 101,
            sessionId: "busy-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 200,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "busy",
            updatedAt: 500
        )
        try writeSession(
            named: "202.json",
            in: sessionsDirectory,
            pid: 202,
            sessionId: "stale-session",
            cwd: "/Users/dariana/old",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "idle",
            updatedAt: 100
        )
        try writeSession(
            named: "303.json",
            in: sessionsDirectory,
            pid: 303,
            sessionId: "waiting-session",
            cwd: "/Users/dariana/personal/prosperis",
            startedAt: 150,
            kind: "bg",
            entrypoint: "cli",
            name: "Review failing CI",
            status: "waiting",
            updatedAt: 300
        )

        let scanner = ClaudeSessionScanner(
            claudeHome: root.url.appending(path: ".claude", directoryHint: .isDirectory),
            processInspector: StubProcessInspector(livePIDs: [101, 303])
        )

        let sessions = try scanner.scan()

        #expect(sessions.map(\.pid) == [101, 303])
        #expect(sessions[0].title == "Untitled chat")
        #expect(sessions[0].displayStatus == .busy)
        #expect(sessions[1].title == "Review failing CI")
        #expect(sessions[1].displayStatus == .waiting)
    }

    @Test
    func scannerInfersRecentlyUpdatedSessionAsBusyWhenStatusIsMissing() throws {
        let root = try TemporaryDirectory()
        let sessionsDirectory = root.url.appending(path: ".claude/sessions", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "404.json",
            in: sessionsDirectory,
            pid: 404,
            sessionId: "statusless-session",
            cwd: "/Users/dariana/personal/Pets",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: nil,
            updatedAt: 1_782_430_000_000
        )

        let scanner = ClaudeSessionScanner(
            claudeHome: root.url.appending(path: ".claude", directoryHint: .isDirectory),
            processInspector: StubProcessInspector(livePIDs: [404]),
            now: { Date(timeIntervalSince1970: 1_782_430_030) }
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].displayStatus == .busy)
    }

    @Test
    func scannerUsesTranscriptTitleAsTitleWhenMetadataNameIsMissing() throws {
        let root = try TemporaryDirectory()
        let claudeHome = root.url.appending(path: ".claude", directoryHint: .isDirectory)
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        let projectDirectory = claudeHome.appending(path: "projects/-Users-dariana-ndp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "909.json",
            in: sessionsDirectory,
            pid: 909,
            sessionId: "slugged-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "idle",
            updatedAt: 200
        )
        try Data("""
        {"type":"user","sessionId":"slugged-session","slug":"zany-crafting-scroll"}
        {"type":"ai-title","aiTitle":"Review checkout failure","sessionId":"slugged-session"}
        """.utf8)
            .write(to: projectDirectory.appending(path: "slugged-session.jsonl"))

        let scanner = ClaudeSessionScanner(
            claudeHome: claudeHome,
            processInspector: StubProcessInspector(livePIDs: [909])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].title == "Review checkout failure")
    }

    @Test
    func scannerUsesLastPromptWhenTranscriptTitleIsMissing() throws {
        let root = try TemporaryDirectory()
        let claudeHome = root.url.appending(path: ".claude", directoryHint: .isDirectory)
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        let projectDirectory = claudeHome.appending(path: "projects/-Users-dariana-ndp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "910.json",
            in: sessionsDirectory,
            pid: 910,
            sessionId: "prompt-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "idle",
            updatedAt: 200
        )
        try Data("""
        {"type":"user","sessionId":"prompt-session","slug":"wild-purple-name"}
        {"type":"last-prompt","lastPrompt":"fix the checkout failure without changing shipping math","sessionId":"prompt-session"}
        """.utf8)
            .write(to: projectDirectory.appending(path: "prompt-session.jsonl"))

        let scanner = ClaudeSessionScanner(
            claudeHome: claudeHome,
            processInspector: StubProcessInspector(livePIDs: [910])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].title == "fix the checkout failure without changing shipping math")
    }

    @Test
    func scannerDoesNotUseCommandNameWhenTranscriptContextExists() throws {
        let root = try TemporaryDirectory()
        let claudeHome = root.url.appending(path: ".claude", directoryHint: .isDirectory)
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        let projectDirectory = claudeHome.appending(path: "projects/-Users-dariana-ndp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "912.json",
            in: sessionsDirectory,
            pid: 912,
            sessionId: "resume-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: "/resume",
            status: "idle",
            updatedAt: 200
        )
        try Data(#"{"type":"ai-title","aiTitle":"Fix checkout validation","sessionId":"resume-session"}"#.utf8)
            .write(to: projectDirectory.appending(path: "resume-session.jsonl"))

        let scanner = ClaudeSessionScanner(
            claudeHome: claudeHome,
            processInspector: StubProcessInspector(livePIDs: [912])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].title == "Fix checkout validation")
    }

    @Test
    func scannerUsesBeginningOfTranscriptAsChatPreview() throws {
        let root = try TemporaryDirectory()
        let claudeHome = root.url.appending(path: ".claude", directoryHint: .isDirectory)
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        let projectDirectory = claudeHome.appending(path: "projects/-Users-dariana-ndp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "911.json",
            in: sessionsDirectory,
            pid: 911,
            sessionId: "preview-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "idle",
            updatedAt: 200
        )
        try Data("""
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"Can you make the settings menu open from the pet overlay?"}]},"sessionId":"preview-session"}
        {"type":"ai-title","aiTitle":"Add settings menu","sessionId":"preview-session"}
        """.utf8)
            .write(to: projectDirectory.appending(path: "preview-session.jsonl"))

        let scanner = ClaudeSessionScanner(
            claudeHome: claudeHome,
            processInspector: StubProcessInspector(livePIDs: [911])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].title == "Add settings menu")
        #expect(sessions[0].chatPreview == "Can you make the settings menu open from the pet overlay?")
    }

    @Test
    func scannerUsesLatestPromptAsDismissalToken() throws {
        let root = try TemporaryDirectory()
        let claudeHome = root.url.appending(path: ".claude", directoryHint: .isDirectory)
        let sessionsDirectory = claudeHome.appending(path: "sessions", directoryHint: .isDirectory)
        let projectDirectory = claudeHome.appending(path: "projects/-Users-dariana-ndp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "913.json",
            in: sessionsDirectory,
            pid: 913,
            sessionId: "latest-prompt-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "busy",
            updatedAt: 200
        )
        try Data("""
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"Original prompt should stay in preview"}]},"sessionId":"latest-prompt-session"}
        {"type":"last-prompt","lastPrompt":"new prompt should drive dismissal reset","sessionId":"latest-prompt-session"}
        """.utf8)
            .write(to: projectDirectory.appending(path: "latest-prompt-session.jsonl"))

        let scanner = ClaudeSessionScanner(
            claudeHome: claudeHome,
            processInspector: StubProcessInspector(livePIDs: [913])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].chatPreview == "Original prompt should stay in preview")
        #expect(sessions[0].dismissalToken == "new prompt should drive dismissal reset")
    }

    @Test
    func scannerMarksBackgroundJobIdAsReplyTarget() throws {
        let root = try TemporaryDirectory()
        let sessionsDirectory = root.url.appending(path: ".claude/sessions", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "505.json",
            in: sessionsDirectory,
            pid: 505,
            sessionId: "background-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "bg",
            entrypoint: "cli",
            name: "Background task",
            jobId: "abc123ef",
            status: "idle",
            updatedAt: 200
        )

        let scanner = ClaudeSessionScanner(
            claudeHome: root.url.appending(path: ".claude", directoryHint: .isDirectory),
            processInspector: StubProcessInspector(livePIDs: [505])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].replyTarget == .background(id: "abc123ef"))
    }

    @Test
    func scannerMarksInteractiveTTYAsReplyTarget() throws {
        let root = try TemporaryDirectory()
        let sessionsDirectory = root.url.appending(path: ".claude/sessions", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        try writeSession(
            named: "606.json",
            in: sessionsDirectory,
            pid: 606,
            sessionId: "interactive-session",
            cwd: "/Users/dariana/ndp",
            startedAt: 100,
            kind: "interactive",
            entrypoint: "cli",
            name: nil,
            status: "waiting",
            updatedAt: 200
        )

        let scanner = ClaudeSessionScanner(
            claudeHome: root.url.appending(path: ".claude", directoryHint: .isDirectory),
            processInspector: StubProcessInspector(livePIDs: [606], terminals: [606: "ttys028"])
        )

        let sessions = try scanner.scan()

        #expect(sessions.count == 1)
        #expect(sessions[0].replyTarget == .terminal(tty: "ttys028"))
    }

    @Test
    func replySenderUsesBackgroundAttachWhenSessionHasBackgroundTarget() throws {
        let launcher = RecordingReplyProcessLauncher()
        let sender = ClaudeReplySender(processLauncher: launcher)
        let session = ClaudeSession(
            pid: 707,
            sessionId: "background-session",
            cwd: "/Users/dariana/ndp",
            title: "Background task",
            kind: "bg",
            entrypoint: "cli",
            displayStatus: .waiting,
            replyTarget: .background(id: "abc123ef"),
            updatedAt: nil,
            startedAt: nil
        )

        try sender.send("please continue", to: session)

        #expect(launcher.runs.count == 1)
        #expect(launcher.runs[0].executable.path == "/usr/bin/script")
        #expect(launcher.runs[0].arguments == ["-q", "/dev/null", "claude", "attach", "abc123ef"])
        #expect(String(data: launcher.runs[0].standardInput, encoding: .utf8) == "\u{1B}[200~please continue\u{1B}[201~\r\u{1A}")
    }

    @Test
    func replySenderSubmitsToTerminalWhenSessionHasTTYTarget() throws {
        let terminalWriter = RecordingTerminalWriter()
        let sender = ClaudeReplySender(terminalWriter: terminalWriter)
        let session = ClaudeSession(
            pid: 808,
            sessionId: "interactive-session",
            cwd: "/Users/dariana/ndp",
            title: "ndp",
            kind: "interactive",
            entrypoint: "cli",
            displayStatus: .waiting,
            replyTarget: .terminal(tty: "ttys028"),
            updatedAt: nil,
            startedAt: nil
        )

        try sender.send("try option 2", to: session)

        #expect(terminalWriter.submissions == [
            TerminalSubmission(tty: "ttys028", message: "try option 2")
        ])
    }

    @Test
    func appleScriptTerminalWriterFocusesTTYAndPressesReturnAfterPaste() throws {
        let focuser = RecordingTerminalTabFocuser(result: true)
        let launcher = RecordingReplyProcessLauncher()
        let writer = AppleScriptTerminalWriter(tabFocuser: focuser, scriptLauncher: launcher)

        try writer.submit("continue the work", toTTY: "ttys028")

        #expect(focuser.requests == ["ttys028"])
        #expect(launcher.runs.count == 1)
        #expect(launcher.runs[0].executable.path == "/usr/bin/osascript")
        #expect(launcher.runs[0].arguments.count == 3)
        #expect(launcher.runs[0].arguments[0] == "-e")
        #expect(launcher.runs[0].arguments[2] == "continue the work")
        #expect(launcher.runs[0].arguments[1].contains("keystroke \"v\" using command down"))
        #expect(launcher.runs[0].arguments[1].contains("key code 36"))
    }

    @Test
    func hostResolverFindsSupportedAncestorThroughHelperChain() {
        let resolver = ClaudeHostAppResolver(
            processInspector: StubActivationProcessInspector(
                snapshots: [
                    66186: ActivationProcessSnapshot(
                        pid: 66186,
                        parentPID: 63569,
                        processName: "claude",
                        executablePath: "/Users/dariana/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude",
                        bundleIdentifier: nil
                    ),
                    63569: ActivationProcessSnapshot(
                        pid: 63569,
                        parentPID: 63111,
                        processName: "Code Helper (Plugin)",
                        executablePath: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)",
                        bundleIdentifier: nil
                    ),
                    63111: ActivationProcessSnapshot(
                        pid: 63111,
                        parentPID: 1,
                        processName: "Code",
                        executablePath: "/Applications/Visual Studio Code.app/Contents/MacOS/Code",
                        bundleIdentifier: "com.microsoft.VSCode"
                    )
                ]
            )
        )

        #expect(resolver.hostApp(for: 66186) == ClaudeHostApp.vscode(pid: 63111))
    }

    @Test
    func hostResolverSupportsRequestedBundleIdentifiers() {
        let cases: [(String, ClaudeHostApp)] = [
            ("com.apple.Terminal", .terminal(pid: 10)),
            ("com.mitchellh.ghostty", .ghostty(pid: 10)),
            ("com.microsoft.VSCode", .vscode(pid: 10)),
            ("com.microsoft.VSCodeInsiders", .vscodeInsiders(pid: 10)),
            ("com.cmuxterm.app", .cmux(pid: 10))
        ]

        for (bundleIdentifier, expectedHost) in cases {
            let resolver = ClaudeHostAppResolver(
                processInspector: StubActivationProcessInspector(
                    snapshots: [
                        100: ActivationProcessSnapshot(
                            pid: 100,
                            parentPID: 10,
                            processName: "claude",
                            executablePath: "/usr/local/bin/claude",
                            bundleIdentifier: nil
                        ),
                        10: ActivationProcessSnapshot(
                            pid: 10,
                            parentPID: 1,
                            processName: "Host",
                            executablePath: "/Applications/Host.app/Contents/MacOS/Host",
                            bundleIdentifier: bundleIdentifier
                        )
                    ]
                )
            )

            #expect(resolver.hostApp(for: 100) == expectedHost)
        }
    }

    @Test
    func sessionActivatorReturnsExactFocusWhenHostFocuserSucceeds() throws {
        let session = makeSession(sessionId: "terminal-session", displayStatus: .waiting)
        let appActivator = RecordingHostAppActivator()
        let activator = ClaudeSessionActivator(
            hostResolver: StaticHostResolver(host: .terminal(pid: 10), processName: "Terminal"),
            hostFocuser: StubHostFocuser(result: .focusedExactTarget(appName: "Terminal")),
            appActivator: appActivator
        )

        let result = try activator.activate(session)

        #expect(result == .focusedExactTarget(appName: "Terminal"))
        #expect(appActivator.activatedHosts == [.terminal(pid: 10)])
    }

    @Test
    func sessionActivatorActivatesHostAppWhenExactFocusIsUnavailable() throws {
        let session = makeSession(sessionId: "ghostty-session", displayStatus: .waiting)
        let appActivator = RecordingHostAppActivator()
        let activator = ClaudeSessionActivator(
            hostResolver: StaticHostResolver(host: .ghostty(pid: 20), processName: "Ghostty"),
            hostFocuser: StubHostFocuser(result: nil),
            appActivator: appActivator
        )

        let result = try activator.activate(session)

        #expect(result == .activatedApp(appName: "Ghostty"))
        #expect(appActivator.activatedHosts == [.ghostty(pid: 20)])
    }

    @Test
    func sessionActivatorReportsUnsupportedHostWhenNoHostAppCanBeResolved() throws {
        let session = makeSession(sessionId: "unknown-session", displayStatus: .waiting)
        let activator = ClaudeSessionActivator(
            hostResolver: StaticHostResolver(host: nil, processName: "claude"),
            hostFocuser: StubHostFocuser(result: nil),
            appActivator: RecordingHostAppActivator()
        )

        let result = try activator.activate(session)

        #expect(result == .unsupportedHost(processName: "claude"))
    }

    @Test
    func sessionActivatorActivatesHostAppWhenPermissionBlocksExactFocus() throws {
        let session = makeSession(sessionId: "vscode-session", displayStatus: .waiting)
        let appActivator = RecordingHostAppActivator()
        let activator = ClaudeSessionActivator(
            hostResolver: StaticHostResolver(host: .vscode(pid: 20), processName: "Code"),
            hostFocuser: StubHostFocuser(
                result: .permissionDenied(
                    reason: "Accessibility permission is required to inspect Visual Studio Code windows."
                )
            ),
            appActivator: appActivator
        )

        let result = try activator.activate(session)

        #expect(result == .permissionDenied(reason: "Accessibility permission is required to inspect Visual Studio Code windows."))
        #expect(appActivator.activatedHosts == [.vscode(pid: 20)])
    }

    @Test
    func compositeHostFocuserRoutesSupportedHosts() throws {
        let recorder = RecordingTerminalTabFocuser(result: true)
        let focuser = CompositeHostAppFocuser(
            terminalFocuser: TerminalHostFocuser(tabFocuser: recorder),
            accessibilityFocuser: StubAccessibilityHostFocuser(result: nil)
        )
        let session = ClaudeSession(
            pid: 808,
            sessionId: "terminal-session",
            cwd: "/Users/dariana/personal/Pets",
            title: "Terminal test",
            kind: "interactive",
            entrypoint: "cli",
            displayStatus: .waiting,
            replyTarget: .terminal(tty: "ttys028"),
            updatedAt: nil,
            startedAt: nil
        )

        let result = try focuser.focus(session: session, host: .terminal(pid: 10))

        #expect(result == .focusedExactTarget(appName: "Terminal"))
        #expect(recorder.requests == ["ttys028"])
    }

    @Test
    func terminalHostFocuserFallsBackWhenSessionHasNoTTY() throws {
        let recorder = RecordingTerminalTabFocuser(result: true)
        let focuser = TerminalHostFocuser(tabFocuser: recorder)
        let session = makeSession(sessionId: "terminal-session", displayStatus: .waiting)

        let result = try focuser.focus(session: session, host: .terminal(pid: 10))

        #expect(result == nil)
        #expect(recorder.requests.isEmpty)
    }

    @Test
    func accessibilityFocuserPermissionDeniedIsReturnedToActivator() throws {
        let focuser = StubAccessibilityHostFocuser(
            result: .permissionDenied(reason: "Accessibility permission is required to inspect Ghostty windows.")
        )

        let result = try focuser.focus(
            session: makeSession(sessionId: "ghostty-session", displayStatus: .waiting),
            host: .ghostty(pid: 20)
        )

        #expect(result == .permissionDenied(reason: "Accessibility permission is required to inspect Ghostty windows."))
    }

    @Test
    func accessibilityFocuserPromptsForPermissionWhenAccessIsMissing() throws {
        let permissionChecker = RecordingAccessibilityPermissionChecker(isTrusted: false)
        let focuser = AccessibilityHostFocuser(permissionChecker: permissionChecker)

        let result = try focuser.focus(
            session: makeSession(sessionId: "vscode-session", displayStatus: .waiting),
            host: .vscode(pid: 20)
        )

        #expect(result == .permissionDenied(reason: "Enable Accessibility permission for Pets to inspect Visual Studio Code windows."))
        #expect(permissionChecker.promptRequests == [true])
    }

    private func writeSession(
        named fileName: String,
        in directory: URL,
        pid: Int32,
        sessionId: String,
        cwd: String,
        startedAt: Int,
        kind: String,
        entrypoint: String,
        name: String?,
        jobId: String? = nil,
        status: String?,
        updatedAt: Int
    ) throws {
        var payload: [String: Any] = [
            "pid": pid,
            "sessionId": sessionId,
            "cwd": cwd,
            "startedAt": startedAt,
            "procStart": "Thu Jun 25 14:23:14 2026",
            "version": "2.1.191",
            "peerProtocol": 1,
            "kind": kind,
            "entrypoint": entrypoint,
            "updatedAt": updatedAt
        ]
        payload["name"] = name
        payload["jobId"] = jobId
        payload["status"] = status

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appending(path: fileName))
    }

    private func makeSession(
        sessionId: String,
        displayStatus: ClaudeDisplayStatus = .idle,
        title: String? = nil,
        chatPreview: String? = nil,
        dismissalToken: String? = nil
    ) -> ClaudeSession {
        ClaudeSession(
            pid: 1,
            sessionId: sessionId,
            cwd: "/Users/dariana/personal/Pets",
            title: title ?? sessionId,
            chatPreview: chatPreview,
            dismissalToken: dismissalToken ?? sessionId,
            kind: "interactive",
            entrypoint: "cli",
            displayStatus: displayStatus,
            updatedAt: nil,
            startedAt: nil
        )
    }
}

private struct StubProcessInspector: ProcessInspecting {
    let livePIDs: Set<Int32>
    var terminals: [Int32: String] = [:]

    func isProcessAlive(pid: Int32) -> Bool {
        livePIDs.contains(pid)
    }

    func terminalName(pid: Int32) -> String? {
        terminals[pid]
    }
}

private final class RecordingReplyProcessLauncher: ReplyProcessLaunching, @unchecked Sendable {
    struct Run {
        let executable: URL
        let arguments: [String]
        let standardInput: Data
    }

    private(set) var runs: [Run] = []

    func run(executable: URL, arguments: [String], standardInput: Data) throws {
        runs.append(Run(executable: executable, arguments: arguments, standardInput: standardInput))
    }
}

private struct TerminalSubmission: Equatable {
    let tty: String
    let message: String
}

private final class RecordingTerminalWriter: TerminalWriting, @unchecked Sendable {
    private(set) var submissions: [TerminalSubmission] = []

    func submit(_ message: String, toTTY tty: String) throws {
        submissions.append(TerminalSubmission(tty: tty, message: message))
    }
}

private struct StubActivationProcessInspector: ActivationProcessInspecting {
    let snapshots: [Int32: ActivationProcessSnapshot]

    func snapshot(pid: Int32) -> ActivationProcessSnapshot? {
        snapshots[pid]
    }
}

private struct StaticHostResolver: HostAppResolving {
    let host: ClaudeHostApp?
    let processName: String?

    func hostApp(for pid: Int32) -> ClaudeHostApp? {
        host
    }

    func processName(for pid: Int32) -> String? {
        processName
    }
}

private final class RecordingHostAppActivator: HostAppActivating, @unchecked Sendable {
    private(set) var activatedHosts: [ClaudeHostApp] = []

    func activate(host: ClaudeHostApp) throws {
        activatedHosts.append(host)
    }
}

private struct StubHostFocuser: HostAppFocusing {
    let result: ClaudeSessionActivationResult?

    func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        result
    }
}

private final class RecordingTerminalTabFocuser: TerminalTabFocusing, @unchecked Sendable {
    let result: Bool
    private(set) var requests: [String] = []

    init(result: Bool) {
        self.result = result
    }

    func focusTab(tty: String) throws -> Bool {
        requests.append(tty)
        return result
    }
}

private struct StubAccessibilityHostFocuser: HostAppFocusing {
    let result: ClaudeSessionActivationResult?

    func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        result
    }
}

private final class RecordingAccessibilityPermissionChecker: AccessibilityPermissionChecking, @unchecked Sendable {
    let isTrusted: Bool
    private(set) var promptRequests: [Bool] = []

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        promptRequests.append(promptIfNeeded)
        return isTrusted
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "PetsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
