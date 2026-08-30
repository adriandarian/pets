import Foundation
import Testing

@Suite
struct PetCollectionViewSourceTests {
    @Test
    func settingsExposePetsChestsAndCollectionAsPeers() throws {
        let source = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(!source.contains("case general"))
        #expect(!source.contains("Label(\"General\""))
        #expect(source.contains("case pets"))
        #expect(source.contains("case chests"))
        #expect(source.contains("case collection"))
        #expect(source.contains("PetChestView(store: store)"))
        #expect(source.contains("PetCollectionView(store: store)"))
        #expect(source.contains("PetSettingsDestination.allCases"))
        #expect(source.contains("case .chests: \"Chests\""))
        #expect(source.contains("case .collection: \"Collection\""))
    }

    @Test
    func chestAndCollectionJourneysAreSeparated() throws {
        let chest = try source("Sources/Pets/PetChestView.swift")
        let components = try source("Sources/Pets/PetChestComponents.swift")
        let conversion = try source("Sources/Pets/PetKeyConversionView.swift")
        let collection = try source("Sources/Pets/PetCollectionViews.swift")

        #expect(chest.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(chest.contains("store.refreshRewardUsage()"))
        #expect(chest.contains("ForEach(PetRarity.allCases"))
        #expect(chest.contains("UnlockedPetSheet"))
        #expect(components.contains("store.openChest(rarity)"))
        #expect(components.contains("PetArtResourceLocator.url(for:"))
        #expect(conversion.contains("5 Common Keys → 1 Rare Key"))
        #expect(conversion.contains("5 Rare Keys → 1 Legendary Key"))
        #expect(collection.contains("struct PetCollectionView: View"))
        #expect(collection.contains("Text(\"Pet Collection\")"))
        #expect(collection.contains("ForEach(selectedCategory.petIDs"))
        #expect(!collection.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(!collection.contains("PetChestCard"))
        #expect(!chest.contains("ForEach(selectedCategory.petIDs"))
    }

    @Test
    func rewardHeaderKeepsProgressInlineAndCompact() throws {
        let source = try source("Sources/Pets/PetChestView.swift")
        let rewardProgress = try sourceSlice(
            source,
            from: "private var rewardProgress",
            to: "private var unlockSheetBinding"
        )

        #expect(rewardProgress.contains("HStack(alignment: .center, spacing: 12)"))
        #expect(rewardProgress.contains(".frame(width: 34, height: 34)"))
        #expect(rewardProgress.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(rewardProgress.contains(".padding(14)"))
    }

    @Test
    func rewardUsageRowsUseTheSharedOfficialProviderLogos() throws {
        let source = try source("Sources/Pets/PetChestComponents.swift")
        let usageSources = try sourceSlice(
            source,
            from: "struct PetUsageSourceStrip",
            to: "struct PetChestCard"
        )

        #expect(usageSources.contains("PetTrackingProvider(rawValue: status.id)"))
        #expect(usageSources.contains("PetProviderIcon("))
        #expect(usageSources.contains("size: 20"))
        #expect(!usageSources.contains("sourceIconName"))
        #expect(!usageSources.contains("\"sparkles\""))
        #expect(!usageSources.contains("\"chevron.left.forwardslash.chevron.right\""))
    }

    @Test
    func rewardUsageSummaryHasBoundedHeightAndMovesOverflowIntoAPopover() throws {
        let chest = try source("Sources/Pets/PetChestView.swift")
        let components = try source("Sources/Pets/PetChestComponents.swift")
        let usageStrip = try sourceSlice(
            components,
            from: "struct PetUsageSourceStrip",
            to: "private struct PetUsageSourceSummary"
        )

        #expect(chest.contains("PetUsageSourceStrip(statuses: store.usageSourceStatuses)"))
        #expect(!chest.contains("ForEach(store.usageSourceStatuses)"))
        #expect(usageStrip.contains("maximumVisibleSources = 3"))
        #expect(usageStrip.contains("statuses.prefix(Self.maximumVisibleSources)"))
        #expect(usageStrip.contains("statuses.dropFirst(Self.maximumVisibleSources)"))
        #expect(usageStrip.contains(#"+\(overflowStatuses.count) more"#))
        #expect(usageStrip.contains(".popover(isPresented: $isShowingOverflow"))
        #expect(usageStrip.contains(".frame(minHeight: 38)"))
    }

    @Test
    func keyBalancesAppearOnlyOnTheirChestCards() throws {
        let chestView = try source("Sources/Pets/PetChestView.swift")
        let chestComponents = try source("Sources/Pets/PetChestComponents.swift")
        let rewardProgress = try sourceSlice(
            chestView,
            from: "private var rewardProgress",
            to: "private var unlockSheetBinding"
        )
        let chestCard = try sourceSlice(
            chestComponents,
            from: "struct PetChestCard",
            to: "struct PetChestArtwork"
        )

        #expect(!chestView.contains("PetKeyBalanceCard"))
        #expect(!rewardProgress.contains("ForEach(PetRarity.allCases"))
        #expect(chestCard.contains("Label(keyBalanceLabel, systemImage: \"key.fill\")"))
        #expect(chestCard.contains("matchingKeyCount == 1 ? \"Key\" : \"Keys\""))
    }

    @Test
    func chestButtonConvertsWhenItsMatchingKeyIsMissing() throws {
        let source = try source("Sources/Pets/PetChestComponents.swift")
        let chestCard = try sourceSlice(
            source,
            from: "struct PetChestCard",
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
        let popover = try source("Sources/Pets/PetKeyConversionView.swift")

        #expect(popover.contains("Slider("))
        #expect(popover.contains("in: 1...Double(maxConversionCount)"))
        #expect(popover.contains("step: 1"))
        #expect(popover.contains("store.upgradeKeys(from: sourceRarity, count: conversionCount)"))
    }

    @Test
    func eachChestUsesTheMatchingRarityKey() throws {
        let source = try source("Sources/Pets/PetChestComponents.swift")

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
        let source = try source("Sources/Pets/PetPickerViews.swift")

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
