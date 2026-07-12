public struct PetSessionTransitionDetector: Sendable {
    private var previousStatuses: [String: HarnessSessionStatus]?

    public init() {}

    @discardableResult
    public mutating func observe(
        _ sessions: [HarnessSession],
        suppressCompletion: Bool = false
    ) -> Bool {
        var currentStatuses: [String: HarnessSessionStatus] = [:]
        for session in sessions {
            currentStatuses[session.id] = session.status
        }

        defer { previousStatuses = currentStatuses }
        guard let previousStatuses else { return false }
        guard !suppressCompletion else { return false }

        return currentStatuses.contains { id, status in
            guard status == .idle, let previousStatus = previousStatuses[id] else {
                return false
            }
            return previousStatus != .idle
        }
    }
}
