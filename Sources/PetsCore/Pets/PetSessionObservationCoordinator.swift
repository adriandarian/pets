public struct PetSessionObservationCoordinator: Sendable {
    private var transitionDetector = PetSessionTransitionDetector()
    private var shouldSuppressCompletionOnNextSuccessfulObservation = false

    public init() {}

    public mutating func recordError(_ error: String?) {
        if error != nil {
            shouldSuppressCompletionOnNextSuccessfulObservation = true
        }
    }

    @discardableResult
    public mutating func observeSuccessfulSessions(_ sessions: [HarnessSession]) -> Bool {
        !observeCompletedHarnessIDs(sessions).isEmpty
    }

    public mutating func observeCompletedHarnessIDs(
        _ sessions: [HarnessSession]
    ) -> Set<String> {
        let suppressCompletion = shouldSuppressCompletionOnNextSuccessfulObservation
        let completedHarnessIDs = transitionDetector.observeCompletedHarnessIDs(
            sessions,
            suppressCompletion: suppressCompletion
        )
        shouldSuppressCompletionOnNextSuccessfulObservation = false
        return completedHarnessIDs
    }
}
