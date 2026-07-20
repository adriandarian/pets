import AppKit
import PetsCore
import SwiftUI

struct PetCollectionView: View {
    @ObservedObject var store: PetStore
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
#if PETS_DEVELOPMENT
                PetDevelopmentControls(store: store)
#endif
                rewardProgress

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        "Open a Chest",
                        detail: "Each chest uses its matching key and always unlocks that rarity."
                    )

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(PetRarity.allCases, id: \.self) { rarity in
                            PetChestCard(store: store, rarity: rarity)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        "Pet Collection",
                        detail: "\(selectedFamilyOwnedCount) of \(selectedCategory.petIDs.count) obtained"
                    )

                    Picker("Pet family", selection: $selectedCategoryID) {
                        ForEach(PetCatalog.builtInCategories, id: \.id) { category in
                            Text(category.displayName)
                                .tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 142), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(selectedCategory.petIDs, id: \.self) { petID in
                            PetCollectionCard(store: store, petID: petID)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: unlockSheetBinding) {
            if let unlockedPetID = store.unlockedPetID {
                UnlockedPetSheet(store: store, petID: unlockedPetID)
            }
        }
    }

    private var rewardProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: store.collectionState.progressFraction)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .accessibilityLabel("Progress to the next pet key")
                        .accessibilityValue(progressAccessibilityValue)

                    HStack {
                        Text("\(exactTokens(store.collectionState.tokenRemainder)) / 500,000,000 tokens")
                            .monospacedDigit()
                        Spacer()
                        Text("\(compactTokens(store.collectionState.tokensUntilNextKey)) to next key")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    store.refreshRewardUsage()
                } label: {
                    if store.isRefreshingRewardUsage {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshingRewardUsage)
                .help("Refresh token usage")
                .accessibilityLabel("Refresh token usage")
            }

            Divider()

            VStack(spacing: 10) {
                ForEach(store.usageSourceStatuses) { status in
                    PetUsageSourceRow(status: status)
                }
            }

            if let collectionError = store.collectionError {
                Label(collectionError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var selectedCategory: PetCatalogCategory {
        PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
            ?? PetCatalog.builtInCategories[0]
    }

    private var selectedFamilyOwnedCount: Int {
        selectedCategory.petIDs.count(where: store.isPetOwned)
    }

    private var unlockSheetBinding: Binding<Bool> {
        Binding(
            get: { store.unlockedPetID != nil },
            set: { isPresented in
                if !isPresented {
                    store.dismissUnlockedPet()
                }
            }
        )
    }

    private var progressAccessibilityValue: String {
        "\(exactTokens(store.collectionState.tokenRemainder)) of 500,000,000 tokens"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if PETS_DEVELOPMENT
private struct PetDevelopmentControls: View {
    @ObservedObject var store: PetStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(.orange.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Development Collection")
                    .font(.headline)
                Text("Keys are unlimited. Collection changes are stored only in Pets Dev.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Unlock All Pets") {
                store.unlockAllPetsForDevelopment()
            }

            Button("Reset Collected Pets", role: .destructive) {
                store.resetCollectedPetsForDevelopment()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.orange.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        }
    }
}
#endif

private struct PetUsageSourceRow: View {
    let status: PetUsageSourceStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sourceIconName)
                .foregroundStyle(status.errorMessage == nil ? Color.secondary : Color.red)
                .frame(width: 18)

            Text(status.displayName)
                .font(.subheadline.weight(.medium))

            if let errorMessage = status.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else if let periodID = status.periodID {
                Text("Week of \(periodID)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(status.tokens.map(compactTokens) ?? "Not scanned")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(status.tokens == nil ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var sourceIconName: String {
        switch status.id {
        case "claude": "sparkles"
        case "copilot": "chevron.left.forwardslash.chevron.right"
        default: "terminal.fill"
        }
    }
}

private struct PetChestCard: View {
    @ObservedObject var store: PetStore
    let rarity: PetRarity
    @State private var isShowingConversion = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(rarity.displayName)
                    .font(.headline)
                Spacer()
                Label(keyBalanceLabel, systemImage: "key.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rarityColor.opacity(0.13), in: Capsule())
                    .foregroundStyle(rarityColor)
                    .accessibilityLabel(keyBalanceAccessibilityLabel)
            }

            PetChestArtwork(rarity: rarity)
                .frame(height: 112)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(isPrimaryActionDisabled ? .tertiary : .secondary)
                .lineLimit(1)

            Button {
                performPrimaryAction()
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlAccentColor))
            .disabled(isPrimaryActionDisabled || store.isRefreshingRewardUsage)
            .help(primaryActionHelp)
            .popover(isPresented: $isShowingConversion, arrowEdge: .bottom) {
                if let conversionSource {
                    PetKeyConversionPopover(
                        store: store,
                        sourceRarity: conversionSource,
                        targetRarity: rarity,
                        maxConversionCount: sourceKeyCount / PetRarity.keyUpgradeCost,
                        isPresented: $isShowingConversion
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(rarityColor.opacity(0.35), lineWidth: 1)
        }
    }

    private var remainingPetIDs: [PetID] {
        store.unownedPetIDs(for: rarity)
    }

    private var matchingKeyCount: Int {
        store.collectionState.keyInventory.count(for: rarity)
    }

    private var keyBalanceLabel: String {
#if PETS_DEVELOPMENT
        "Unlimited \(rarity.displayName) Keys"
#else
        "\(matchingKeyCount) \(rarity.displayName) \(matchingKeyCount == 1 ? "Key" : "Keys")"
#endif
    }

    private var keyBalanceAccessibilityLabel: String {
#if PETS_DEVELOPMENT
        "Unlimited \(rarity.displayName.lowercased()) keys available"
#else
        "\(matchingKeyCount) \(rarity.displayName.lowercased()) \(matchingKeyCount == 1 ? "key" : "keys") available"
#endif
    }

    private var hasMatchingKey: Bool {
#if PETS_DEVELOPMENT
        true
#else
        matchingKeyCount > 0
#endif
    }

    private var conversionSource: PetRarity? {
        switch rarity {
        case .common: nil
        case .rare: .common
        case .legendary: .rare
        }
    }

    private var sourceKeyCount: Int {
        guard let conversionSource else { return 0 }
        return store.collectionState.keyInventory.count(for: conversionSource)
    }

    private var canConvert: Bool {
        sourceKeyCount >= PetRarity.keyUpgradeCost
    }

    private var isPrimaryActionDisabled: Bool {
        if remainingPetIDs.isEmpty {
            return true
        }
        if hasMatchingKey {
            return false
        }
        guard conversionSource != nil else { return true }
        return !canConvert
    }

    private var primaryActionTitle: String {
        if hasMatchingKey || conversionSource == nil {
            return "Open \(rarity.displayName) Chest"
        }
        return "Convert to \(rarity.displayName) Key"
    }

    private var primaryActionSystemImage: String {
        hasMatchingKey || conversionSource == nil ? "key.fill" : "arrow.up.circle.fill"
    }

    private var primaryActionHelp: String {
        if remainingPetIDs.isEmpty {
            return "Every \(rarity.displayName.lowercased()) pet is already collected"
        }
        if isPrimaryActionDisabled {
            return statusText
        }
        return primaryActionTitle
    }

    private func performPrimaryAction() {
        if hasMatchingKey {
            store.openChest(rarity)
        } else if conversionSource != nil, canConvert {
            isShowingConversion = true
        }
    }

    private var statusText: String {
        if remainingPetIDs.isEmpty {
            return "All collected"
        }
        if hasMatchingKey {
            return "\(remainingPetIDs.count) \(remainingPetIDs.count == 1 ? "pet" : "pets") remaining"
        }
        guard let conversionSource else {
            return "Need 1 \(rarity.displayName) Key"
        }
        if canConvert {
            let available = sourceKeyCount / PetRarity.keyUpgradeCost
            return "\(available) \(available == 1 ? "conversion" : "conversions") available"
        }
        let missing = PetRarity.keyUpgradeCost - sourceKeyCount
        return "Need \(missing) more \(conversionSource.displayName) \(missing == 1 ? "Key" : "Keys") to convert"
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: .secondary
        case .rare: .blue
        case .legendary: .orange
        }
    }
}

private struct PetKeyConversionPopover: View {
    @ObservedObject var store: PetStore
    let sourceRarity: PetRarity
    let targetRarity: PetRarity
    let maxConversionCount: Int
    @Binding var isPresented: Bool
    @State private var conversionCount = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Convert to \(targetRarity.displayName) Keys")
                    .font(.headline)
                Text(rateDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Keys to create")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(conversionCount.formatted())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                HStack {
                    Text("1")
                    Slider(
                        value: conversionSliderValue,
                        in: 1...Double(maxConversionCount),
                        step: 1
                    )
                    .accessibilityLabel("\(targetRarity.displayName) Keys to create")
                    .accessibilityValue(conversionCount.formatted())
                    Text(maxConversionCount.formatted())
                }

                Text(conversionSummary)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(conversionAccessibilityLabel)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }

                Spacer()

                Button(confirmButtonTitle) {
                    store.upgradeKeys(from: sourceRarity, count: conversionCount)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 330)
    }

    private var conversionSliderValue: Binding<Double> {
        Binding(
            get: { Double(conversionCount) },
            set: { conversionCount = Int($0.rounded()) }
        )
    }

    private var sourceKeysUsed: Int {
        conversionCount * PetRarity.keyUpgradeCost
    }

    private var rateDescription: String {
        switch sourceRarity {
        case .common: "5 Common Keys → 1 Rare Key"
        case .rare: "5 Rare Keys → 1 Legendary Key"
        case .legendary: "Legendary Keys cannot be upgraded"
        }
    }

    private var conversionSummary: String {
        "\(sourceKeysUsed) \(sourceRarity.displayName) Keys → \(conversionCount) \(targetRarity.displayName) \(conversionCount == 1 ? "Key" : "Keys")"
    }

    private var conversionAccessibilityLabel: String {
        "Use \(sourceKeysUsed) \(sourceRarity.displayName.lowercased()) keys to create \(conversionCount) \(targetRarity.displayName.lowercased()) \(conversionCount == 1 ? "key" : "keys")"
    }

    private var confirmButtonTitle: String {
        "Convert \(conversionCount) \(conversionCount == 1 ? "Key" : "Keys")"
    }
}

struct PetChestArtwork: View {
    let rarity: PetRarity

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Closed \(rarity.displayName.lowercased()) pet chest")
    }

    private var image: NSImage? {
        guard let url = PetArtResourceLocator.url(for: resource) else { return nil }
        return NSImage(contentsOf: url)
    }

    private var resource: PetChestArtResource {
        switch rarity {
        case .common: .common
        case .rare: .rare
        case .legendary: .legendary
        }
    }
}

private struct PetCollectionCard: View {
    @ObservedObject var store: PetStore
    let petID: PetID

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.secondary.opacity(isOwned ? 0.08 : 0.045))

                PetSprite(
                    petID: petID,
                    visualContext: PetVisualContext(
                        status: .idle,
                        hasActiveSessions: true,
                        isHovered: false,
                        animationSettings: .default
                    ),
                    pixelation: .off
                )
                .frame(width: 78, height: 78)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.34)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(systemName: isOwned ? "checkmark.circle.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOwned ? Color.accentColor : Color.secondary)
                    .padding(7)
                    .accessibilityLabel(isOwned ? "Obtained" : "Missing")
            }
            .frame(height: 92)

            Text(PetCatalog.displayName(for: petID))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isOwned {
                Label("Obtained", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 22)
            } else {
                Label(
                    "Missing · \(PetCatalog.rarity(for: petID).displayName)",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 22)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var isOwned: Bool {
        store.isPetOwned(petID)
    }
}

private func compactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.notation(.compactName))
}

private func exactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.grouping(.automatic))
}
