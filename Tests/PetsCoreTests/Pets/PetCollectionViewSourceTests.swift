import Foundation
import Testing

@Suite
struct PetCollectionViewSourceTests {
    @Test
    func settingsExposeCollectionAlongsidePets() throws {
        let source = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(!source.contains("case general"))
        #expect(!source.contains("Label(\"General\""))
        #expect(source.contains("case pets"))
        #expect(source.contains("case collection"))
        #expect(source.contains("PetCollectionView(store: store)"))
        #expect(source.contains("Label(\"Collection\", systemImage: \"square.grid.2x2\")"))
    }

    @Test
    func collectionHubContainsTheCoreRewardJourney() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")

        #expect(source.contains("struct PetCollectionView: View"))
        #expect(!source.contains("Text(\"Pet Keys\")"))
        #expect(!source.contains("Every 500 million combined tokens earns one Common Key."))
        #expect(source.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(source.contains("store.refreshRewardUsage()"))
        #expect(source.contains("PetKeyConversionPopover"))
        #expect(source.contains("Slider("))
        #expect(source.contains("5 Common Keys → 1 Rare Key"))
        #expect(source.contains("5 Rare Keys → 1 Legendary Key"))
        #expect(source.contains("ForEach(PetRarity.allCases"))
        #expect(source.contains("store.openChest(rarity)"))
        #expect(source.contains("PetArtResourceLocator.url(for:"))
        #expect(source.contains("\"Pet Collection\""))
        #expect(source.contains("UnlockedPetSheet"))
    }

    @Test
    func rewardHeaderKeepsProgressInlineAndCompact() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")
        let rewardProgress = try sourceSlice(
            source,
            from: "private var rewardProgress",
            to: "private var selectedCategory"
        )

        #expect(rewardProgress.contains("HStack(alignment: .center, spacing: 12)"))
        #expect(rewardProgress.contains(".frame(width: 34, height: 34)"))
        #expect(rewardProgress.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(rewardProgress.contains(".padding(14)"))
    }

    @Test
    func keyBalancesAppearOnlyOnTheirChestCards() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")
        let rewardProgress = try sourceSlice(
            source,
            from: "private var rewardProgress",
            to: "private var selectedCategory"
        )
        let chestCard = try sourceSlice(
            source,
            from: "private struct PetChestCard",
            to: "private struct PetKeyConversionPopover"
        )

        #expect(!source.contains("PetKeyBalanceCard"))
        #expect(!rewardProgress.contains("ForEach(PetRarity.allCases"))
        #expect(chestCard.contains("Label(keyBalanceLabel, systemImage: \"key.fill\")"))
        #expect(chestCard.contains("matchingKeyCount == 1 ? \"Key\" : \"Keys\""))
    }

    @Test
    func chestButtonConvertsWhenItsMatchingKeyIsMissing() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")
        let chestCard = try sourceSlice(
            source,
            from: "private struct PetChestCard",
            to: "struct PetChestArtwork"
        )

        #expect(chestCard.contains("store.openChest(rarity)"))
        #expect(chestCard.contains("isShowingConversion = true"))
        #expect(chestCard.contains("Convert to \\(rarity.displayName) Key"))
        #expect(chestCard.contains("Need \\(missing) more \\(conversionSource.displayName)"))
        #expect(chestCard.contains("sourceKeyCount >= PetRarity.keyUpgradeCost"))
    }

    @Test
    func conversionPopoverChoosesAnAffordableBulkAmount() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")
        let popover = try sourceSlice(
            source,
            from: "private struct PetKeyConversionPopover",
            to: "struct PetChestArtwork"
        )

        #expect(popover.contains("Slider("))
        #expect(popover.contains("in: 1...Double(maxConversionCount)"))
        #expect(popover.contains("step: 1"))
        #expect(popover.contains("store.upgradeKeys(from: sourceRarity, count: conversionCount)"))
    }

    @Test
    func eachChestUsesTheMatchingRarityKey() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")

        #expect(source.contains("store.collectionState.keyInventory.count(for: rarity)"))
        #expect(source.contains("keyBalanceLabel"))
    }

    @Test
    func collectionBrowsesOneCatalogFamilyAtATime() throws {
        let collectionSource = try source("Sources/Pets/PetCollectionViews.swift")
        let revealSource = try source("Sources/Pets/PetChestRevealView.swift")

        #expect(collectionSource.contains("@State private var selectedCategoryID"))
        #expect(collectionSource.contains("Picker(\"Pet family\", selection: $selectedCategoryID)"))
        #expect(collectionSource.contains("ForEach(PetCatalog.builtInCategories"))
        #expect(collectionSource.contains("ForEach(selectedCategory.petIDs"))
        #expect(collectionSource.contains("\"Obtained\""))
        #expect(collectionSource.contains("\"Missing · \\(PetCatalog.rarity(for: petID).displayName)\""))
        #expect(revealSource.contains("PetCatalog.category(for: petID)?.displayName"))
        #expect(!collectionSource.contains("Cloud Pet"))
        #expect(!collectionSource.contains("Label(\"Add\", systemImage: \"plus\")"))
    }

    @Test
    func unlockRevealIsBrowseOnly() throws {
        let source = try source("Sources/Pets/PetChestRevealView.swift")

        #expect(source.contains("Button(\"Done\")"))
        #expect(!source.contains("Add to Desktop"))
        #expect(!source.contains("store.addPet(petID: petID)"))
    }

    @Test
    func unlockRevealStagesTheChestBeforeShowingThePet() throws {
        let source = try source("Sources/Pets/PetChestRevealView.swift")
        let reveal = try sourceSlice(
            source,
            from: "struct UnlockedPetSheet",
            to: "private enum ChestRevealPhase"
        )

        #expect(reveal.contains("@State private var revealPhase = ChestRevealPhase.closed"))
        #expect(reveal.contains("Self.shakeSequence"))
        #expect(reveal.contains("ChestOpeningArtwork(rarity: rarity, lidOpenAmount: lidOpenAmount)"))
        #expect(reveal.contains("revealPhase = .opening"))
        #expect(reveal.contains("revealPhase = .revealed"))
        #expect(reveal.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(reveal.contains(".interactiveDismissDisabled(revealPhase != .revealed)"))
        #expect(reveal.contains(".allowsHitTesting(revealPhase == .revealed)"))
    }

    @Test
    func unlockRevealUsesDedicatedOpenChestArtAndSparkles() throws {
        let source = try source("Sources/Pets/PetChestRevealView.swift")

        #expect(!source.contains(".rotation3DEffect("))
        #expect(source.contains("PetOpenChestArtwork(rarity: rarity)"))
        #expect(source.contains("PetArtResourceLocator.url(forOpenChest: resource)"))
        #expect(source.contains(".blendMode(.screen)"))
        #expect(source.contains("ChestSparkleField(color: rarityColor)"))
        #expect(source.contains(".opacity(revealPhase == .revealed ? 0 : 1)"))
    }

    @Test
    func spritePickerShowsLockedSpeciesButCannotSelectThem() throws {
        let source = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(source.contains("isOwned: store.isPetOwned(petID)"))
        #expect(source.contains(".disabled(!isOwned)"))
        #expect(source.contains("Label(\"Locked\", systemImage: \"lock.fill\")"))
    }

    private func source(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/" {
            if FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path) {
                return try String(contentsOf: root.appending(path: path), encoding: .utf8)
            }
            root.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func sourceSlice(_ source: String, from start: String, to end: String) throws -> String {
        let startIndex = try #require(source.range(of: start)?.lowerBound)
        let endIndex = try #require(source.range(of: end, range: startIndex..<source.endIndex)?.lowerBound)
        return String(source[startIndex..<endIndex])
    }
}
