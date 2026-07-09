public struct PetDismissedSession: Hashable, Sendable {
    public let sessionID: String
    public let dismissalToken: String

    public init(sessionID: String, dismissalToken: String) {
        self.sessionID = sessionID
        self.dismissalToken = dismissalToken
    }

    public init(session: HarnessSession) {
        self.init(sessionID: session.id, dismissalToken: session.dismissalToken)
    }
}

public enum PetDismissedSessionFilter {
    public static func visibleSessions(
        _ sessions: [HarnessSession],
        dismissedSessions: Set<PetDismissedSession>
    ) -> [HarnessSession] {
        sessions.filter { session in
            !isEmptyUntitledSession(session)
                && !dismissedSessions.contains(PetDismissedSession(session: session))
        }
    }

    private static func isEmptyUntitledSession(_ session: HarnessSession) -> Bool {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatPreview = session.chatPreview?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title == "Untitled chat" && (chatPreview?.isEmpty ?? true)
    }
}
