import Foundation
import PetsCore

struct PetSettingsPersistence {
    private enum DefaultsKey {
        static let petInstances = "petInstances"
        static let petInstancesBackup = "petInstancesBackup"
        static let selectedPetInstanceID = "selectedPetInstanceID"
        static let selectedPetID = "selectedPetID"
        static let spritePixelation = "spritePixelation"
        static let sessionContextLineCount = "sessionContextLineCount"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPetConfiguration() -> (instances: [PetInstance], selectedID: PetInstance.ID?, error: String?) {
        let legacyPetID = PetCatalog.resolvedPetID(
            defaults.string(forKey: DefaultsKey.selectedPetID).map(PetID.init(rawValue:))
                ?? PetCatalog.defaultPetID
        )
        let legacyPixelation = PetCatalog.pixelation(
            PetSpritePixelation.persisted(rawValue: defaults.string(forKey: DefaultsKey.spritePixelation)),
            allowedFor: legacyPetID
        )
        let persistedContextLineCount = defaults.integer(forKey: DefaultsKey.sessionContextLineCount)
        let legacyContextLineCount = PetSessionContextLineCount.clamped(
            persistedContextLineCount == 0
                ? PetSessionContextLineCount.defaultValue
                : persistedContextLineCount
        )

        let loaded = loadPetInstances(
            migratedPetID: legacyPetID,
            migratedPixelation: legacyPixelation,
            migratedContextLineCount: legacyContextLineCount
        )
        let selectedID = defaults.string(forKey: DefaultsKey.selectedPetInstanceID)
            .flatMap(UUID.init(uuidString:))
            .flatMap { persistedID in
                loaded.instances.contains(where: { $0.id == persistedID }) ? persistedID : nil
            }
            ?? loaded.instances.first?.id

        return (loaded.instances, selectedID, loaded.error)
    }

    func persistPetInstances(_ petInstances: [PetInstance]) {
        guard let data = try? JSONEncoder().encode(petInstances) else { return }
        if let currentData = defaults.data(forKey: DefaultsKey.petInstances),
           currentData != data {
            defaults.set(currentData, forKey: DefaultsKey.petInstancesBackup)
        }
        defaults.set(data, forKey: DefaultsKey.petInstances)
    }

    func persistSelectedPetInstanceID(_ selectedPetInstanceID: PetInstance.ID?) {
        if let selectedPetInstanceID {
            defaults.set(selectedPetInstanceID.uuidString, forKey: DefaultsKey.selectedPetInstanceID)
        } else {
            defaults.removeObject(forKey: DefaultsKey.selectedPetInstanceID)
        }
    }

    private func loadPetInstances(
        migratedPetID: PetID,
        migratedPixelation: PetSpritePixelation,
        migratedContextLineCount: Int
    ) -> (instances: [PetInstance], error: String?) {
        if let data = defaults.data(forKey: DefaultsKey.petInstances) {
            backupPetInstancesIfNeeded(data)
            do {
                let decoded = try JSONDecoder().decode([PetInstance].self, from: data)
                return (decoded.map { $0.normalizedForCurrentCatalog() }, nil)
            } catch {
                if let backupData = defaults.data(forKey: DefaultsKey.petInstancesBackup),
                   backupData != data,
                   let decoded = try? JSONDecoder().decode([PetInstance].self, from: backupData) {
                    return (
                        decoded.map { $0.normalizedForCurrentCatalog() },
                        "Pet settings were restored from the last compatible backup."
                    )
                }
                return (
                    [],
                    "Pet settings could not be loaded. Defaults were restored."
                )
            }
        }

        let migrated = PetInstance.migratedDefault(
            petID: migratedPetID,
            pixelation: migratedPixelation,
            sessionContextLineCount: migratedContextLineCount
        )
        return ([migrated], nil)
    }

    private func backupPetInstancesIfNeeded(_ data: Data) {
        guard defaults.data(forKey: DefaultsKey.petInstancesBackup) == nil else { return }
        defaults.set(data, forKey: DefaultsKey.petInstancesBackup)
    }
}
