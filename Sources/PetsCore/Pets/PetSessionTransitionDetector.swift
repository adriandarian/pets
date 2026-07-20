public struct PetSessionTransitionDetector: Sendable {
    private var previousStatuses: [String: HarnessSessionStatus]?

    public init() {}

    @discardableResult
    public mutating func observe(
        _ sessions: [HarnessSession],
        suppressCompletion: Bool = false
    ) -> Bool {
        !observeCompletedHarnessIDs(
            sessions,
            suppressCompletion: suppressCompletion
        ).isEmpty
    }

    public mutating func observeCompletedHarnessIDs(
        _ sessions: [HarnessSession],
        suppressCompletion: Bool = false
    ) -> Set<String> {
        var currentStatuses: [String: HarnessSessionStatus] = [:]
        for session in sessions {
            currentStatuses[session.id] = session.status
        }

        defer { previousStatuses = currentStatuses }
        guard let previousStatuses else { return [] }
        guard !suppressCompletion else { return [] }

        return Set(sessions.compactMap { session in
            guard session.status == .idle,
                  let previousStatus = previousStatuses[session.id],
                  previousStatus != .idle
            else {
                return nil
            }
            return session.harnessID
        })
    }
}
