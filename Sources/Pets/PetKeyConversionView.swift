import PetsCore
import SwiftUI

struct PetKeyConversionPopover: View {
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
                Button("Cancel", role: .cancel) { isPresented = false }
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
