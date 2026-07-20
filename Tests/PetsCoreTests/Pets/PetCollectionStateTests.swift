import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetCollectionStateTests {
    @Test
    func starterAndConfiguredPetsAreOwnedAfterNormalization() {
        let state = PetCollectionState().normalized(
            grandfathering: [.cirrusCloud, .snowCloud]
        )

        #expect(state.ownedPetIDs == [.cuteCloud, .cirrusCloud, .snowCloud])
    }

    @Test
    func releaseGiftPolicyMatchesTheUpdateEconomy() throws {
        let routine = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "0.2.1",
            configuredTier: nil
        ))
        let major = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "0.3.0",
            configuredTier: "major"
        ))
        let anniversary = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "1.0.0",
            configuredTier: "anniversary"
        ))

        #expect(routine.keyInventory == PetKeyInventory(common: 1))
        #expect(major.keyInventory == PetKeyInventory(common: 2))
        #expect(anniversary.keyInventory == PetKeyInventory(rare: 1))
        #expect(PetReleaseGiftTier.allCases.allSatisfy {
            $0.keyInventory.count(for: .legendary) == 0
        })
    }

    @Test
    func releaseGiftPolicyDefaultsUnknownMetadataToRoutineAndRejectsInvalidVersions() throws {
        let fallback = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "v0.4.0",
            configuredTier: "surprise"
        ))

        #expect(fallback.version == "0.4.0")
        #expect(fallback.tier == .routine)
        #expect(PetReleaseGiftPolicy.gift(
            installedVersion: "development",
            configuredTier: "major"
        ) == nil)
    }

    @Test
    func eachReleaseGiftCanOnlyBeClaimedOnce() throws {
        var state = PetCollectionState()
        let routine = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "0.2.0",
            configuredTier: "routine"
        ))
        let major = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "0.3.0",
            configuredTier: "major"
        ))

        let didClaimRoutine = state.claimReleaseGift(routine)
        let didReclaimRoutine = state.claimReleaseGift(routine)
        let didClaimMajor = state.claimReleaseGift(major)

        #expect(didClaimRoutine)
        #expect(!didReclaimRoutine)
        #expect(didClaimMajor)
        #expect(state.keyInventory == PetKeyInventory(common: 3))
        #expect(state.claimedReleaseGiftVersions == ["0.2.0", "0.3.0"])
    }

    @Test
    func claimedReleaseGiftsSurvivePersistenceRoundTrips() throws {
        var state = PetCollectionState()
        let gift = try #require(PetReleaseGiftPolicy.gift(
            installedVersion: "1.0.0",
            configuredTier: "anniversary"
        ))
        _ = state.claimReleaseGift(gift)

        let data = try JSONEncoder().encode(state)
        var restored = try JSONDecoder().decode(PetCollectionState.self, from: data)
        let didReclaimGift = restored.claimReleaseGift(gift)

        #expect(restored.keyInventory == PetKeyInventory(rare: 1))
        #expect(!didReclaimGift)
        #expect(restored.claimedReleaseGiftVersions == ["1.0.0"])
    }

    @Test
    func combinedProviderTokensEarnKeysAndCarryTheRemainder() {
        var state = PetCollectionState()

        #expect(state.apply(PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 375_000_000
        )) == 0)
        #expect(state.apply(PetUsageReading(
            providerID: "codex",
            periodID: "2026-07-13",
            tokens: 225_000_000
        )) == 1)

        #expect(state.keyInventory.count(for: .common) == 1)
        #expect(state.keyInventory.count(for: .rare) == 0)
        #expect(state.keyInventory.count(for: .legendary) == 0)
        #expect(state.tokenRemainder == 100_000_000)
    }

    @Test
    func repeatedAndLowerReadingsCannotMintKeysTwice() {
        var state = PetCollectionState()
        let reading = PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 588_000_000
        )

        #expect(state.apply(reading) == 1)
        #expect(state.apply(reading) == 0)
        #expect(state.apply(PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 500_000_000
        )) == 0)
        #expect(state.keyInventory.count(for: .common) == 1)
        #expect(state.tokenRemainder == 88_000_000)
        #expect(state.providerCheckpoints["claude"]?.observedTokens == 588_000_000)
    }

    @Test
    func aNewProviderPeriodCountsItsCurrentTotal() {
        var state = PetCollectionState()

        _ = state.apply(PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-06",
            tokens: 490_000_000
        ))
        #expect(state.apply(PetUsageReading(
            providerID: "claude",
            periodID: "2026-07-13",
            tokens: 20_000_000
        )) == 1)

        #expect(state.keyInventory.count(for: .common) == 1)
        #expect(state.tokenRemainder == 10_000_000)
    }

    @Test
    func keysUpgradeUpwardAtFiveToOne() throws {
        var state = PetCollectionState(
            keyInventory: PetKeyInventory(common: 10, rare: 4)
        )

        #expect(try state.upgradeKeys(from: .common) == .rare)
        #expect(state.keyInventory == PetKeyInventory(common: 5, rare: 5))

        #expect(try state.upgradeKeys(from: .rare) == .legendary)
        #expect(state.keyInventory == PetKeyInventory(common: 5, legendary: 1))
    }

    @Test
    func multipleKeySetsUpgradeInOneAtomicConversion() throws {
        var state = PetCollectionState(
            keyInventory: PetKeyInventory(common: 12)
        )

        #expect(try state.upgradeKeys(from: .common, count: 2) == .rare)
        #expect(state.keyInventory == PetKeyInventory(common: 2, rare: 2))
    }

    @Test
    func invalidKeyUpgradesNeverSpendKeys() {
        var insufficient = PetCollectionState(
            keyInventory: PetKeyInventory(common: 4)
        )
        #expect(throws: PetKeyUpgradeError.insufficientKeys(rarity: .common, required: 5)) {
            try insufficient.upgradeKeys(from: .common)
        }
        #expect(insufficient.keyInventory == PetKeyInventory(common: 4))

        var highestTier = PetCollectionState(
            keyInventory: PetKeyInventory(legendary: 5)
        )
        #expect(throws: PetKeyUpgradeError.highestRarity(.legendary)) {
            try highestTier.upgradeKeys(from: .legendary)
        }
        #expect(highestTier.keyInventory == PetKeyInventory(legendary: 5))

        var invalidCount = PetCollectionState(
            keyInventory: PetKeyInventory(common: 10)
        )
        #expect(throws: PetKeyUpgradeError.invalidConversionCount) {
            try invalidCount.upgradeKeys(from: .common, count: 0)
        }
        #expect(invalidCount.keyInventory == PetKeyInventory(common: 10))
    }

    @Test
    func openingAChestSpendsOnlyItsMatchingKey() throws {
        var state = PetCollectionState(
            ownedPetIDs: [.cuteCloud],
            keyInventory: PetKeyInventory(common: 1, rare: 2, legendary: 3)
        )

        let unlocked = try state.openChest(
            rarity: .common,
            eligiblePetIDs: [.cuteCloud, .nimbusCloud],
            selectionIndex: 0
        )

        #expect(unlocked == .nimbusCloud)
        #expect(state.ownedPetIDs.contains(.nimbusCloud))
        #expect(state.keyInventory == PetKeyInventory(rare: 2, legendary: 3))
    }

    @Test
    func everyTesslingCanBeUnlockedFromItsRarityChest() throws {
        let tesslings: [(petID: PetID, rarity: PetRarity)] = [
            (.knotling, .common),
            (.prismite, .rare),
            (.orbitling, .legendary),
        ]

        for tessling in tesslings {
            var state = PetCollectionState(
                keyInventory: PetKeyInventory(rarity: tessling.rarity, count: 1)
            )
            let unlocked = try state.openChest(
                rarity: tessling.rarity,
                eligiblePetIDs: [tessling.petID],
                selectionIndex: 0
            )

            #expect(unlocked == tessling.petID)
            #expect(state.ownedPetIDs.contains(tessling.petID))
            #expect(state.keyInventory.count(for: tessling.rarity) == 0)
        }
    }

    @Test
    func legendaryChestCanOnlyReturnALegendaryPet() throws {
        var state = PetCollectionState(
            keyInventory: PetKeyInventory(legendary: 1)
        )

        let unlocked = try state.openChest(
            rarity: .legendary,
            eligiblePetIDs: [.knotling, .prismite, .orbitling],
            selectionIndex: 0
        )

        #expect(unlocked == .orbitling)
        #expect(PetCatalog.rarity(for: unlocked) == .legendary)
    }

    @Test
    func chestValidationNeverSpendsKeys() {
        var insufficient = PetCollectionState(
            keyInventory: PetKeyInventory(common: 99)
        )
        #expect(throws: PetChestOpenError.insufficientKeys(rarity: .rare, required: 1)) {
            try insufficient.openChest(
                rarity: .rare,
                eligiblePetIDs: [.cirrusCloud],
                selectionIndex: 0
            )
        }
        #expect(insufficient.keyInventory == PetKeyInventory(common: 99))

        var exhausted = PetCollectionState(
            ownedPetIDs: [.cuteCloud, .nimbusCloud],
            keyInventory: PetKeyInventory(common: 1)
        )
        #expect(throws: PetChestOpenError.allPetsCollected(rarity: .common)) {
            try exhausted.openChest(
                rarity: .common,
                eligiblePetIDs: [.cuteCloud, .nimbusCloud],
                selectionIndex: 0
            )
        }
        #expect(exhausted.keyInventory == PetKeyInventory(common: 1))
    }

    @Test
    func selectionIndexIsClampedToTheUnownedCandidates() throws {
        var state = PetCollectionState(
            keyInventory: PetKeyInventory(rare: 1)
        )
        let unlocked = try state.openChest(
            rarity: .rare,
            eligiblePetIDs: [.cirrusCloud, .lenticularCloud],
            selectionIndex: 99
        )

        #expect(unlocked == .lenticularCloud)
        #expect(state.keyInventory.count(for: .rare) == 0)
    }

    @Test
    func legacySharedKeysMigrateToCommonKeys() throws {
        struct LegacyCollectionState: Codable {
            let ownedPetIDs: Set<PetID>
            let keyCount: Int
            let tokenRemainder: Int64
            let providerCheckpoints: [String: PetUsageCheckpoint]
        }

        let data = try JSONEncoder().encode(LegacyCollectionState(
            ownedPetIDs: [.cuteCloud, .cirrusCloud],
            keyCount: 7,
            tokenRemainder: 25,
            providerCheckpoints: [:]
        ))

        let state = try JSONDecoder().decode(PetCollectionState.self, from: data)
        #expect(state.ownedPetIDs.contains(.cirrusCloud))
        #expect(state.keyInventory == PetKeyInventory(common: 7))
        #expect(state.tokenRemainder == 25)
        #expect(state.claimedReleaseGiftVersions.isEmpty)
    }
}
