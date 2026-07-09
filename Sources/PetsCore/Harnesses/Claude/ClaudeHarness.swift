public struct ClaudeHarness: PetHarness {
    public static let defaultID = "claude"
    public static let defaultDisplayName = "Claude Code"

    public let id = ClaudeHarness.defaultID
    public let displayName = ClaudeHarness.defaultDisplayName

    private let scanner: ClaudeSessionScanner
    private let replySender: ClaudeReplySender
    private let sessionActivator: any SessionActivating

    public init(
        scanner: ClaudeSessionScanner = ClaudeSessionScanner(),
        replySender: ClaudeReplySender = ClaudeReplySender(),
        sessionActivator: any SessionActivating = ClaudeSessionActivator()
    ) {
        self.scanner = scanner
        self.replySender = replySender
        self.sessionActivator = sessionActivator
    }

    public func scan() throws -> [HarnessSession] {
        try scanner.scan().map { session in
            session.harnessSession(harnessID: id, harnessDisplayName: displayName)
        }
    }

    public func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        try sessionActivator.activate(ClaudeSession(harnessSession: session)).harnessResult
    }

    public func sendReply(_ message: String, to session: HarnessSession) throws {
        try replySender.send(message, to: ClaudeSession(harnessSession: session))
    }
}

private extension ClaudeSessionActivationResult {
    var harnessResult: HarnessActivationResult {
        switch self {
        case let .focusedExactTarget(appName):
            return .focusedExactTarget(appName: appName)
        case let .activatedApp(appName):
            return .activatedApp(appName: appName)
        case let .unsupportedHost(processName):
            return .unsupportedHost(processName: processName)
        case let .permissionDenied(reason):
            return .permissionDenied(reason: reason)
        }
    }
}
