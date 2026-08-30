import AppKit
import PetsCore
import SwiftUI

struct PetUsageSourceRow: View {
    let status: PetUsageSourceStatus

    var body: some View {
        HStack(spacing: 10) {
            if let provider = PetTrackingProvider(rawValue: status.id) {
                PetProviderIcon(
                    provider: provider,
                    isDisabled: status.errorMessage != nil,
                    size: 20
                )
            } else {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(status.errorMessage == nil ? Color.secondary : Color.red)
                    .frame(width: 20, height: 20)
            }
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
            Text(status.tokens.map(petCompactTokens) ?? "Not scanned")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(status.tokens == nil ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PetChestCard: View {
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
        if remainingPetIDs.isEmpty { return true }
        if hasMatchingKey { return false }
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
        return isPrimaryActionDisabled ? statusText : primaryActionTitle
    }

    private func performPrimaryAction() {
        if hasMatchingKey {
            store.openChest(rarity)
        } else if conversionSource != nil, canConvert {
            isShowingConversion = true
        }
    }

    private var statusText: String {
        if remainingPetIDs.isEmpty { return "All collected" }
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
