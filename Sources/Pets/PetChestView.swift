import AppKit
import PetsCore
import SwiftUI

struct PetChestView: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
#if PETS_DEVELOPMENT
            PetDevelopmentControls(store: store)
#endif
            rewardProgress

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Open a Chest")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Text("Each chest uses its matching key and always unlocks that rarity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    ForEach(PetRarity.allCases, id: \.self) { rarity in
                        PetChestCard(store: store, rarity: rarity)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                        Text("\(petExactTokens(store.collectionState.tokenRemainder)) / 500,000,000 tokens")
                            .monospacedDigit()
                        Spacer()
                        Text("\(petCompactTokens(store.collectionState.tokensUntilNextKey)) to next key")
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

            VStack(spacing: 8) {
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var unlockSheetBinding: Binding<Bool> {
        Binding(
            get: { store.unlockedPetID != nil },
            set: { isPresented in
                if !isPresented { store.dismissUnlockedPet() }
            }
        )
    }

    private var progressAccessibilityValue: String {
        "\(petExactTokens(store.collectionState.tokenRemainder)) of 500,000,000 tokens"
    }
}

#if PETS_DEVELOPMENT
private struct PetDevelopmentControls: View {
    @ObservedObject var store: PetStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Development Collection")
                    .font(.headline)
                Text("Unlimited keys · isolated Pets Dev collection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unlock All Pets") { store.unlockAllPetsForDevelopment() }
            Button("Reset Collected Pets", role: .destructive) {
                store.resetCollectedPetsForDevelopment()
            }
        }
        .padding(10)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        }
    }
}
#endif

func petCompactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.notation(.compactName))
}

func petExactTokens(_ tokens: Int64) -> String {
    tokens.formatted(.number.grouping(.automatic))
}
