@testable import PetsCore
import Testing

@Suite
struct PetCompletionReactionExpiryTests {
    @Test
    func staleExpiryCannotInvalidateRestartedCompletion() {
        var expiry = PetCompletionReactionExpiry()
        let staleGeneration = expiry.restart()
        let currentGeneration = expiry.restart()

        let staleExpiryWasInvalidated = expiry.invalidate(ifCurrent: staleGeneration)
        let currentExpiryWasInvalidated = expiry.invalidate(ifCurrent: currentGeneration)
        let repeatedExpiryWasInvalidated = expiry.invalidate(ifCurrent: currentGeneration)

        #expect(!staleExpiryWasInvalidated)
        #expect(currentExpiryWasInvalidated)
        #expect(!repeatedExpiryWasInvalidated)
    }
}
