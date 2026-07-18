import Foundation
import PetsCore

struct PetCollectionPersistence {
    private enum DefaultsKey {
        static let collectionState = "petCollectionState"
        static let collectionStateBackup = "petCollectionStateBackup"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(grandfathering petIDs: [PetID]) -> (state: PetCollectionState, error: String?) {
        guard let data = defaults.data(forKey: DefaultsKey.collectionState) else {
            return (PetCollectionState().normalized(grandfathering: petIDs), nil)
        }
        backupCollectionStateIfNeeded(data)

        do {
            let state = try JSONDecoder().decode(PetCollectionState.self, from: data)
            return (state.normalized(grandfathering: petIDs), nil)
        } catch {
            if let backupData = defaults.data(forKey: DefaultsKey.collectionStateBackup),
               backupData != data,
               let state = try? JSONDecoder().decode(PetCollectionState.self, from: backupData) {
                return (
                    state.normalized(grandfathering: petIDs),
                    "Pet collection progress was restored from the last compatible backup."
                )
            }
            return (
                PetCollectionState().normalized(grandfathering: petIDs),
                "Pet collection progress could not be loaded. Starter ownership was restored."
            )
        }
    }

    func persist(_ state: PetCollectionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        if let currentData = defaults.data(forKey: DefaultsKey.collectionState),
           currentData != data {
            defaults.set(currentData, forKey: DefaultsKey.collectionStateBackup)
        }
        defaults.set(data, forKey: DefaultsKey.collectionState)
    }

    private func backupCollectionStateIfNeeded(_ data: Data) {
        guard defaults.data(forKey: DefaultsKey.collectionStateBackup) == nil else { return }
        defaults.set(data, forKey: DefaultsKey.collectionStateBackup)
    }
}
