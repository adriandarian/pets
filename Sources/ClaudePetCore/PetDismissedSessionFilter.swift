public struct PetDismissedSession: Hashable, Sendable {
    public let sessionID: String
    public let dismissalToken: String

    public init(sessionID: String, dismissalToken: String) {
        self.sessionID = sessionID
        self.dismissalToken = dismissalToken
    }

    public init(session: ClaudeSession) {
        self.init(sessionID: session.sessionId, dismissalToken: session.dismissalToken)
    }
}

public enum PetDismissedSessionFilter {
    public static func visibleSessions(
        _ sessions: [ClaudeSession],
        dismissedSessions: Set<PetDismissedSession>
    ) -> [ClaudeSession] {
        sessions.filter { session in
            !isEmptyUntitledSession(session)
                && !dismissedSessions.contains(PetDismissedSession(session: session))
        }
    }

    private static func isEmptyUntitledSession(_ session: ClaudeSession) -> Bool {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatPreview = session.chatPreview?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title == "Untitled chat" && (chatPreview?.isEmpty ?? true)
    }
}
