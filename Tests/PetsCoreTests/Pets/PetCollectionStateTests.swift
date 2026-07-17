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

        #expect(state.keyCount == 1)
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
        #expect(state.keyCount == 1)
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

        #expect(state.keyCount == 1)
        #expect(state.tokenRemainder == 10_000_000)
    }

    @Test
    func openingAChestSpendsKeysAndSelectsOnlyAnUnownedPet() throws {
        var state = PetCollectionState(
            ownedPetIDs: [.cuteCloud],
            keyCount: 3
        )

        let unlocked = try state.openChest(
            rarity: .common,
            eligiblePetIDs: [.cuteCloud, .nimbusCloud],
            selectionIndex: 0
        )

        #expect(unlocked == .nimbusCloud)
        #expect(state.ownedPetIDs.contains(.nimbusCloud))
        #expect(state.keyCount == 2)
    }

    @Test
    func everyTesslingCanBeUnlockedFromItsRarityChest() throws {
        let tesslings: [(petID: PetID, rarity: PetRarity)] = [
            (.knotling, .common),
            (.prismite, .rare),
            (.orbitling, .legendary),
        ]

        for tessling in tesslings {
            var state = PetCollectionState(keyCount: tessling.rarity.keyCost)
            let unlocked = try state.openChest(
                rarity: tessling.rarity,
                eligiblePetIDs: [tessling.petID],
                selectionIndex: 0
            )

            #expect(unlocked == tessling.petID)
            #expect(state.ownedPetIDs.contains(tessling.petID))
            #expect(state.keyCount == 0)
        }
    }

    @Test
    func chestValidationNeverSpendsKeys() {
        var insufficient = PetCollectionState(keyCount: 1)
        #expect(throws: PetChestOpenError.insufficientKeys(required: 2)) {
            try insufficient.openChest(
                rarity: .rare,
                eligiblePetIDs: [.cirrusCloud],
                selectionIndex: 0
            )
        }
        #expect(insufficient.keyCount == 1)

        var exhausted = PetCollectionState(
            ownedPetIDs: [.cuteCloud, .nimbusCloud],
            keyCount: 4
        )
        #expect(throws: PetChestOpenError.allPetsCollected(rarity: .common)) {
            try exhausted.openChest(
                rarity: .common,
                eligiblePetIDs: [.cuteCloud, .nimbusCloud],
                selectionIndex: 0
            )
        }
        #expect(exhausted.keyCount == 4)
    }

    @Test
    func selectionIndexIsClampedToTheUnownedCandidates() throws {
        var state = PetCollectionState(keyCount: 4)
        let unlocked = try state.openChest(
            rarity: .rare,
            eligiblePetIDs: [.cirrusCloud, .lenticularCloud],
            selectionIndex: 99
        )

        #expect(unlocked == .lenticularCloud)
        #expect(state.keyCount == 2)
    }
}
