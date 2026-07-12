import Foundation

package struct PetCompletionReactionExpiry {
    package struct Generation: Equatable {
        fileprivate let id: UUID
    }

    private var currentGeneration: Generation?

    package init() {}

    package mutating func restart() -> Generation {
        let generation = Generation(id: UUID())
        currentGeneration = generation
        return generation
    }

    package mutating func cancel() {
        currentGeneration = nil
    }

    @discardableResult
    package mutating func invalidate(ifCurrent generation: Generation) -> Bool {
        guard currentGeneration == generation else { return false }
        currentGeneration = nil
        return true
    }
}
