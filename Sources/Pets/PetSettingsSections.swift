import AppKit
import PetsCore
import SwiftUI

struct PetTrackingSection: View {
    @ObservedObject var store: PetStore
    let pet: PetInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(PetTrackingProvider.allCases.enumerated()), id: \.element) { index, provider in
                trackerRow(provider)
                if index < PetTrackingProvider.allCases.count - 1 { Divider() }
            }

            Text("Each provider can be tracked by one pet. A pet can track any combination—or nothing at all.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private func trackerRow(_ provider: PetTrackingProvider) -> some View {
        let assignedPet = store.trackingPet(for: provider)
        let isAssignedElsewhere = assignedPet.map { $0.id != pet.id } ?? false

        return HStack(spacing: 12) {
            PetProviderIcon(provider: provider, isDisabled: isAssignedElsewhere)
            Text(provider.displayName)
            Spacer()
            if isAssignedElsewhere {
                Text("Tracked by \(assignedPet?.name ?? "another pet")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Toggle(provider.displayName, isOn: trackingBinding(provider))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isAssignedElsewhere)
        }
        .padding(.vertical, 11)
    }

    private func trackingBinding(_ provider: PetTrackingProvider) -> Binding<Bool> {
        Binding(
            get: { store.petInstance(for: pet.id)?.trackingProviders.contains(provider) == true },
            set: { store.setTrackingProvider(provider, isEnabled: $0, for: pet.id) }
        )
    }
}

struct PetBehaviorSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(spacing: 0) {
            SettingSwitchRow(
                "Hover bounce",
                detail: "Adds a playful lift when your pointer moves over the pet.",
                isOn: animationBinding(\.isHoverBounceEnabled)
            )
            Divider()
            SettingSwitchRow(
                "Idle motion",
                detail: "Keeps the pet gently moving when no sessions are active.",
                isOn: animationBinding(\.isIdleMotionEnabled)
            )
            Divider()
            SettingSwitchRow(
                "Status moods",
                detail: "Reflects session activity through expressions and poses.",
                isOn: animationBinding(\.areStatusMoodsEnabled)
            )
            Divider()
            AnimationFrameRateRow(framesPerSecond: frameRateBinding)
        }
    }

    private var selectedPet: PetInstance {
        store.selectedPetInstance ?? PetInstance.defaultInstance()
    }

    private func animationBinding(
        _ keyPath: WritableKeyPath<PetAnimationSettings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { selectedPet.animationSettings[keyPath: keyPath] },
            set: { value in
                var settings = selectedPet.animationSettings
                settings[keyPath: keyPath] = value
                store.updateSelectedPetAnimationSettings(settings)
            }
        )
    }

    private var frameRateBinding: Binding<Int> {
        Binding(
            get: { selectedPet.animationSettings.framesPerSecond },
            set: { framesPerSecond in
                var settings = selectedPet.animationSettings
                settings.framesPerSecond = PetAnimationFrameRate.clamped(framesPerSecond)
                store.updateSelectedPetAnimationSettings(settings)
            }
        )
    }
}

private struct AnimationFrameRateRow: View {
    @Binding var framesPerSecond: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Animation frame rate")
                Spacer()
                Text("\(framesPerSecond) FPS")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(framesPerSecond) },
                    set: { framesPerSecond = Int($0.rounded()) }
                ),
                in: frameRateSliderRange,
                step: 1
            )
            .accessibilityLabel("Animation frame rate")
            .accessibilityValue("\(framesPerSecond) frames per second")
            Text("Lower frame rates reduce animation work; higher rates make motion smoother.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var frameRateSliderRange: ClosedRange<Double> {
        let lowerBound = Double(PetAnimationFrameRate.supportedRange.lowerBound)
        let upperBound = Double(PetAnimationFrameRate.supportedRange.upperBound)
        return lowerBound...upperBound
    }
}

private struct SettingSwitchRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    init(_ title: String, detail: String, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
                .accessibilityHint(detail)
        }
        .padding(.vertical, 12)
    }
}
