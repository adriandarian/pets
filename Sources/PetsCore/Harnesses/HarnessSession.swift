import Foundation

public enum HarnessSessionStatus: String, CaseIterable, Equatable, Sendable {
    case busy
    case waiting
    case idle
    case unknown

    public var isRunning: Bool {
        self == .busy
    }

    public var usesContinuousSpriteMotion: Bool {
        self == .busy || self == .waiting
    }
}

public enum HarnessReplyTarget: Equatable, Sendable {
    case background(id: String)
    case terminal(tty: String)
    case harnessSpecific(id: String)
}

public struct HarnessSession: Identifiable, Equatable, Sendable {
    public let harnessID: String
    public let harnessDisplayName: String
    public let sessionID: String
    public let processID: Int32?
    public let cwd: String
    public let title: String
    public let chatPreview: String?
    public let dismissalToken: String
    public let kind: String
    public let entrypoint: String
    public let status: HarnessSessionStatus
    public let replyTarget: HarnessReplyTarget?
    public let updatedAt: Date?
    public let startedAt: Date?

    public var id: String {
        "\(harnessID):\(sessionID)"
    }

    public var supportsReply: Bool {
        replyTarget != nil
    }

    public init(
        harnessID: String,
        harnessDisplayName: String,
        sessionID: String,
        processID: Int32?,
        cwd: String,
        title: String,
        chatPreview: String? = nil,
        dismissalToken: String? = nil,
        kind: String,
        entrypoint: String,
        status: HarnessSessionStatus,
        replyTarget: HarnessReplyTarget? = nil,
        updatedAt: Date?,
        startedAt: Date?
    ) {
        self.harnessID = harnessID
        self.harnessDisplayName = harnessDisplayName
        self.sessionID = sessionID
        self.processID = processID
        self.cwd = cwd
        self.title = title
        self.chatPreview = chatPreview
        self.dismissalToken = dismissalToken
            ?? chatPreview
            ?? updatedAt.map { "\($0.timeIntervalSince1970)" }
            ?? title
        self.kind = kind
        self.entrypoint = entrypoint
        self.status = status
        self.replyTarget = replyTarget
        self.updatedAt = updatedAt
        self.startedAt = startedAt
    }
}

public extension HarnessSession {
    static func collapsedChatCount<S: Sequence>(in sessions: S) -> Int where S.Element == HarnessSession {
        sessions.reduce(0) { count, _ in count + 1 }
    }

    static func unreadChatCount<S: Sequence>(in sessions: S) -> Int where S.Element == HarnessSession {
        sessions.reduce(0) { count, session in
            session.status == .waiting ? count + 1 : count
        }
    }
}

public enum HarnessActivationResult: Equatable, Sendable {
    case focusedExactTarget(appName: String)
    case activatedApp(appName: String)
    case unsupportedHost(processName: String?)
    case permissionDenied(reason: String)
}

public protocol PetHarness: Sendable {
    var id: String { get }
    var displayName: String { get }

    func scan() throws -> [HarnessSession]
    func activate(_ session: HarnessSession) throws -> HarnessActivationResult
    func sendReply(_ message: String, to session: HarnessSession) throws
}
