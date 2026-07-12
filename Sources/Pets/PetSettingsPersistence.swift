import Foundation
import PetsCore

struct PetSettingsPersistence {
    private enum DefaultsKey {
        static let petInstances = "petInstances"
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
            do {
                let decoded = try JSONDecoder().decode([PetInstance].self, from: data)
                return (decoded.map { $0.normalizedForCurrentCatalog() }, nil)
            } catch {
                return (
                    [],
                    "Pet settings could not be loaded. Defaults were restored."
                )
            }
        }

        _ = PetInstance.migratedDefault(
            petID: migratedPetID,
            pixelation: migratedPixelation,
            sessionContextLineCount: migratedContextLineCount
        )
        return ([], nil)
    }
}
