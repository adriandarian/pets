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
        let suppressCompletion = shouldSuppressCompletionOnNextSuccessfulObservation
        let didCompleteSession = transitionDetector.observe(
            sessions,
            suppressCompletion: suppressCompletion
        )
        shouldSuppressCompletionOnNextSuccessfulObservation = false
        return didCompleteSession
    }
}
