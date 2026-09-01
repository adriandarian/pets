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
                    Text(selectedConversionCount.formatted())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if maximumConversionCount > 1 {
                    HStack {
                        Text("1")
                        Slider(
                            value: conversionSliderValue,
                            in: 1...Double(maximumConversionCount),
                            step: 1
                        )
                        .accessibilityLabel("\(targetRarity.displayName) Keys to create")
                        .accessibilityValue(selectedConversionCount.formatted())
                        Text(maximumConversionCount.formatted())
                    }
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
                    store.upgradeKeys(from: sourceRarity, count: selectedConversionCount)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(maxConversionCount < 1)
            }
        }
        .padding(18)
        .frame(width: 330)
    }

    private var conversionSliderValue: Binding<Double> {
        Binding(
            get: { Double(selectedConversionCount) },
            set: {
                conversionCount = min(
                    max(1, Int($0.rounded())),
                    maximumConversionCount
                )
            }
        )
    }

    private var maximumConversionCount: Int {
        max(1, maxConversionCount)
    }

    private var selectedConversionCount: Int {
        min(max(1, conversionCount), maximumConversionCount)
    }

    private var sourceKeysUsed: Int {
        selectedConversionCount * PetRarity.keyUpgradeCost
    }

    private var rateDescription: String {
        switch sourceRarity {
        case .common: "5 Common Keys → 1 Rare Key"
        case .rare: "5 Rare Keys → 1 Legendary Key"
        case .legendary: "Legendary Keys cannot be upgraded"
        }
    }

    private var conversionSummary: String {
        "\(sourceKeysUsed) \(sourceRarity.displayName) Keys → \(selectedConversionCount) \(targetRarity.displayName) \(selectedConversionCount == 1 ? "Key" : "Keys")"
    }

    private var conversionAccessibilityLabel: String {
        "Use \(sourceKeysUsed) \(sourceRarity.displayName.lowercased()) keys to create \(selectedConversionCount) \(targetRarity.displayName.lowercased()) \(selectedConversionCount == 1 ? "key" : "keys")"
    }

    private var confirmButtonTitle: String {
        "Convert \(selectedConversionCount) \(selectedConversionCount == 1 ? "Key" : "Keys")"
    }
}
