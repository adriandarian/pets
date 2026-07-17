import AppKit
import PetsCore
import SwiftUI

struct PetCollectionView: View {
    @ObservedObject var store: PetStore
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Pet Keys")
                        .font(.headline)
                    Text("Every 500 million combined tokens earns one Common Key.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)

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

            HStack(alignment: .top, spacing: 10) {
                ForEach(PetRarity.allCases, id: \.self) { rarity in
                    PetKeyBalanceCard(store: store, rarity: rarity)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
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
        .padding(18)
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

private struct PetKeyBalanceCard: View {
    @ObservedObject var store: PetStore
    let rarity: PetRarity

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "key.fill")
                    .foregroundStyle(rarityColor)
                Text("\(rarity.displayName) Keys")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(keyCount.formatted())
                    .font(.title3.bold().monospacedDigit())
            }

            if let nextRarity = rarity.nextRarity {
                Text(upgradeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    store.upgradeKeys(from: rarity)
                } label: {
                    Label("Upgrade to \(nextRarity.displayName)", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(keyCount < PetRarity.keyUpgradeCost)
                .help(upgradeHelp(nextRarity: nextRarity))
            } else {
                Text("Opens Legendary Chests")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(rarityColor.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(rarityColor.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var keyCount: Int {
        store.collectionState.keyInventory.count(for: rarity)
    }

    private var upgradeDescription: String {
        switch rarity {
        case .common: "5 Common Keys → 1 Rare Key"
        case .rare: "5 Rare Keys → 1 Legendary Key"
        case .legendary: ""
        }
    }

    private func upgradeHelp(nextRarity: PetRarity) -> String {
        if keyCount >= PetRarity.keyUpgradeCost {
            return "Convert 5 \(rarity.displayName.lowercased()) keys into 1 \(nextRarity.displayName.lowercased()) key"
        }
        let missing = PetRarity.keyUpgradeCost - keyCount
        return "Need \(missing) more \(rarity.displayName.lowercased()) \(missing == 1 ? "key" : "keys")"
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: .secondary
        case .rare: .blue
        case .legendary: .orange
        }
    }
}

private struct PetUsageSourceRow: View {
    let status: PetUsageSourceStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.id == "claude" ? "sparkles" : "terminal.fill")
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
}

private struct PetChestCard: View {
    @ObservedObject var store: PetStore
    let rarity: PetRarity

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(rarity.displayName)
                    .font(.headline)
                Spacer()
                Label("1 \(rarity.displayName) Key", systemImage: "key.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rarityColor.opacity(0.13), in: Capsule())
                    .foregroundStyle(rarityColor)
                    .accessibilityLabel("Costs 1 \(rarity.displayName.lowercased()) key")
            }

            PetChestArtwork(rarity: rarity)
                .frame(height: 112)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(disabledReason == nil ? .secondary : .tertiary)
                .lineLimit(1)

            Button {
                store.openChest(rarity)
            } label: {
                Label("Open \(rarity.displayName) Chest", systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlAccentColor))
            .disabled(disabledReason != nil || store.isRefreshingRewardUsage)
            .help(disabledReason ?? "Open a \(rarity.displayName.lowercased()) chest")
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

    private var disabledReason: String? {
        if remainingPetIDs.isEmpty {
            return "All collected"
        }
        if store.collectionState.keyInventory.count(for: rarity) < 1 {
            return "Need 1 \(rarity.displayName) Key"
        }
        return nil
    }

    private var statusText: String {
        disabledReason ?? "\(remainingPetIDs.count) \(remainingPetIDs.count == 1 ? "pet" : "pets") remaining"
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: .secondary
        case .rare: .blue
        case .legendary: .orange
        }
    }
}

private struct PetChestArtwork: View {
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

private struct UnlockedPetSheet: View {
    @ObservedObject var store: PetStore
    let petID: PetID

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text("New Pet Unlocked")
                .font(.title2.bold())

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
            .frame(width: 150, height: 150)

            VStack(spacing: 4) {
                Text(PetCatalog.displayName(for: petID))
                    .font(.title3.weight(.semibold))
                Text("\(PetCatalog.rarity(for: petID).displayName) Cloud Pet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                store.dismissUnlockedPet()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 420, height: 430)
    }
}

private func compactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.notation(.compactName))
}

private func exactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.grouping(.automatic))
}
