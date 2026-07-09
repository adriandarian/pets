import Foundation

public enum ClaudeDisplayStatus: String, CaseIterable, Equatable, Sendable {
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

public enum ClaudeReplyTarget: Equatable, Sendable {
    case background(id: String)
    case terminal(tty: String)
}

public struct ClaudeSession: Identifiable, Equatable, Sendable {
    public let id: String
    public let pid: Int32
    public let sessionId: String
    public let cwd: String
    public let title: String
    public let chatPreview: String?
    public let dismissalToken: String
    public let kind: String
    public let entrypoint: String
    public let displayStatus: ClaudeDisplayStatus
    public let replyTarget: ClaudeReplyTarget?
    public let updatedAt: Date?
    public let startedAt: Date?

    public init(
        pid: Int32,
        sessionId: String,
        cwd: String,
        title: String,
        chatPreview: String? = nil,
        dismissalToken: String? = nil,
        kind: String,
        entrypoint: String,
        displayStatus: ClaudeDisplayStatus,
        replyTarget: ClaudeReplyTarget? = nil,
        updatedAt: Date?,
        startedAt: Date?
    ) {
        self.id = sessionId
        self.pid = pid
        self.sessionId = sessionId
        self.cwd = cwd
        self.title = title
        self.chatPreview = chatPreview
        self.dismissalToken = dismissalToken
            ?? chatPreview
            ?? updatedAt.map { "\($0.timeIntervalSince1970)" }
            ?? title
        self.kind = kind
        self.entrypoint = entrypoint
        self.displayStatus = displayStatus
        self.replyTarget = replyTarget
        self.updatedAt = updatedAt
        self.startedAt = startedAt
    }
}

public extension ClaudeSession {
    static func collapsedChatCount<S: Sequence>(in sessions: S) -> Int where S.Element == ClaudeSession {
        sessions.reduce(0) { count, _ in count + 1 }
    }

    static func unreadChatCount<S: Sequence>(in sessions: S) -> Int where S.Element == ClaudeSession {
        sessions.reduce(0) { count, session in
            session.displayStatus == .waiting ? count + 1 : count
        }
    }
}
