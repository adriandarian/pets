import AppKit
import PetsCore
import SwiftUI

struct PetTrackingSection: View {
    @ObservedObject var store: PetStore
    let pet: PetInstance
    @State private var searchText = ""
    @State private var selectedFilter = TrackerFilter.all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            trackerSummary
            trackerSearchField
            trackerFilters

            if filteredProviders.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: trackerColumns, alignment: .leading, spacing: 10) {
                        ForEach(filteredProviders, id: \.self) { provider in
                            trackerTile(provider)
                        }
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
            }

            Text("One pet per tracker. Chat status is available for Claude Code, Codex, and Copilot.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: pet.id) { _, _ in
            searchText = ""
            selectedFilter = .all
        }
    }

    private var trackerSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Trackers")
                .font(.headline)
            Text("\(activeProviderCount) active · \(availableProviderCount) available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var trackerSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search trackers", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear tracker search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var trackerFilters: some View {
        HStack(spacing: 8) {
            ForEach(TrackerFilter.allCases, id: \.self) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    Text(filter.title)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 13)
                        .frame(height: 30)
                        .background(
                            selectedFilter == filter ? Color.accentColor : Color.clear,
                            in: Capsule()
                        )
                        .overlay {
                            if selectedFilter != filter {
                                Capsule()
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            }
                        }
                        .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(emptyStateTitle)
                .font(.headline)
            if !searchText.isEmpty {
                Text("Try another name or clear the search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func trackerTile(_ provider: PetTrackingProvider) -> some View {
        let assignedPet = store.trackingPet(for: provider)
        let isAssignedElsewhere = assignedPet.map { $0.id != pet.id } ?? false
        let isActive = activeProviders.contains(provider)

        return PetTrackerTile(
            provider: provider,
            isActive: isActive,
            assignedPetName: isAssignedElsewhere ? assignedPet?.name : nil
        ) {
            store.setTrackingProvider(provider, isEnabled: !isActive, for: pet.id)
        }
    }

    private var trackerColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118, maximum: 170), spacing: 10)]
    }

    private var activeProviders: Set<PetTrackingProvider> {
        store.petInstance(for: pet.id)?.trackingProviders ?? []
    }

    private var activeProviderCount: Int {
        activeProviders.count
    }

    private var availableProviderCount: Int {
        PetTrackingProvider.allCases.filter { provider in
            guard let assignedPet = store.trackingPet(for: provider) else { return true }
            return assignedPet.id == pet.id
        }.count
    }

    private var filteredProviders: [PetTrackingProvider] {
        PetTrackingProvider.allCases.filter { provider in
            let matchesSearch = searchText.isEmpty
                || provider.displayName.localizedCaseInsensitiveContains(searchText)
            guard matchesSearch else { return false }

            switch selectedFilter {
            case .all:
                return true
            case .active:
                return activeProviders.contains(provider)
            case .available:
                guard let assignedPet = store.trackingPet(for: provider) else { return true }
                return assignedPet.id == pet.id
            }
        }
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty { return "No trackers found" }
        switch selectedFilter {
        case .active:
            return "No active trackers"
        case .all, .available:
            return "No trackers available"
        }
    }
}

private enum TrackerFilter: String, CaseIterable {
    case all
    case active
    case available

    var title: String {
        rawValue.capitalized
    }
}

private struct PetTrackerTile: View {
    let provider: PetTrackingProvider
    let isActive: Bool
    let assignedPetName: String?
    let toggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: toggle) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    PetProviderIcon(
                        provider: provider,
                        isDisabled: isAssignedElsewhere,
                        size: 30
                    )

                    Text(provider.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let assignedPetName {
                        Text("Tracked by \(assignedPetName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)

                selectionIndicator
                    .padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(tileFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tileBorder, lineWidth: isActive ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isAssignedElsewhere)
        .onHover { isHovering = $0 }
        .help(helpText)
        .accessibilityLabel(provider.displayName)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isAssignedElsewhere ? "Assigned trackers cannot be selected." : "Toggle tracker")
    }

    private var isAssignedElsewhere: Bool {
        assignedPetName != nil
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isAssignedElsewhere {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        } else if isActive {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private var tileFill: Color {
        if isActive {
            return Color.accentColor.opacity(isHovering ? 0.18 : 0.11)
        }
        if isHovering && !isAssignedElsewhere {
            return Color.primary.opacity(0.055)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var tileBorder: Color {
        if isActive { return Color.accentColor.opacity(0.9) }
        if isHovering && !isAssignedElsewhere { return Color.primary.opacity(0.18) }
        return Color(nsColor: .separatorColor)
    }

    private var helpText: String {
        if let assignedPetName {
            return "Tracked by \(assignedPetName)"
        }
        return isActive ? "Stop tracking \(provider.displayName)" : "Track \(provider.displayName)"
    }

    private var accessibilityValue: String {
        if let assignedPetName {
            return "Tracked by \(assignedPetName)"
        }
        return isActive ? "Active" : "Inactive"
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
