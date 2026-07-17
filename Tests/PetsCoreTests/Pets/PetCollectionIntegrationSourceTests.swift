import Foundation
import Testing

@Suite
struct PetCollectionIntegrationSourceTests {
    @Test
    func collectionPersistenceIsSeparateAndGrandfathersConfiguredPets() throws {
        let source = try source("Sources/Pets/PetCollectionPersistence.swift")

        #expect(source.contains("static let collectionState = \"petCollectionState\""))
        #expect(source.contains("normalized(grandfathering:"))
        #expect(source.contains("JSONEncoder().encode(state)"))
    }

    @Test
    func storeRefreshesRewardsOnASlowerScheduleAndPublishesRevealState() throws {
        let source = try source("Sources/Pets/PetStore.swift")

        #expect(source.contains("static let rewardRefreshInterval: Duration = .seconds(15 * 60)"))
        #expect(source.contains("@Published private(set) var collectionState"))
        #expect(source.contains("@Published private(set) var unlockedPetID"))
        #expect(source.contains("func refreshRewardUsage()"))
        #expect(source.contains("func upgradeKeys(from rarity: PetRarity, count: Int = 1)"))
        #expect(source.contains("func openChest(_ rarity: PetRarity)"))
        #expect(source.contains("func addPet(petID: PetID)"))
    }

    @Test
    func storePreventsLockedSpeciesFromBeingConfigured() throws {
        let source = try source("Sources/Pets/PetStore.swift")

        #expect(source.contains("guard isPetOwned(petID) else { return }"))
        #expect(source.contains("func isPetOwned(_ petID: PetID) -> Bool"))
    }

    private func source(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/" {
            let package = root.appending(path: "Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return try String(contentsOf: root.appending(path: path), encoding: .utf8)
            }
            root.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
