import Foundation
import PetsCore

struct PetCollectionPersistence {
    private enum DefaultsKey {
        static let collectionState = "petCollectionState"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(grandfathering petIDs: [PetID]) -> (state: PetCollectionState, error: String?) {
        guard let data = defaults.data(forKey: DefaultsKey.collectionState) else {
            return (PetCollectionState().normalized(grandfathering: petIDs), nil)
        }

        do {
            let state = try JSONDecoder().decode(PetCollectionState.self, from: data)
            return (state.normalized(grandfathering: petIDs), nil)
        } catch {
            return (
                PetCollectionState().normalized(grandfathering: petIDs),
                "Pet collection progress could not be loaded. Starter ownership was restored."
            )
        }
    }

    func persist(_ state: PetCollectionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: DefaultsKey.collectionState)
    }
}
