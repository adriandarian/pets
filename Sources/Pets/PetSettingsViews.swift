import AppKit
import SwiftUI
import PetsCore

struct PetSettingsView: View {
    @ObservedObject var store: PetStore
    let toggleOpenAtLogin: (Bool) -> Void
    let respawnSelectedPet: () -> Void

    var body: some View {
        TabView {
            GeneralSettingsPane(
                store: store,
                toggleOpenAtLogin: toggleOpenAtLogin
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            PetConfigurationPane(
                store: store,
                respawnSelectedPet: respawnSelectedPet
            )
            .tabItem {
                Label("Pets", systemImage: "pawprint")
            }
        }
        .frame(width: 900, height: 620)
        .scenePadding()
        .tint(SettingsDesignPalette.accent)
        .preferredColorScheme(.dark)
    }
}

private enum SettingsDesignPalette {
    static let root = Color(red: 0.08, green: 0.12, blue: 0.10)
    static let panel = Color(red: 0.13, green: 0.18, blue: 0.15)
    static let panelRaised = Color(red: 0.16, green: 0.22, blue: 0.18)
    static let inset = Color(red: 0.10, green: 0.14, blue: 0.12)
    static let border = Color.white.opacity(0.11)
    static let selectedFill = Color(red: 0.20, green: 0.36, blue: 0.34)
    static let accent = Color(red: 0.38, green: 0.78, blue: 0.72)
    static let accentStrong = Color(red: 0.27, green: 0.58, blue: 0.52)
    static let switchPink = Color(red: 1.00, green: 0.41, blue: 0.66)
    static let switchTeal = Color(red: 0.40, green: 0.85, blue: 0.81)
}

private struct GeneralSettingsPane: View {
    @ObservedObject var store: PetStore
    let toggleOpenAtLogin: (Bool) -> Void

    var body: some View {
        Form {
            Toggle("Open at Login", isOn: openAtLoginBinding)
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.isOpenAtLoginEnabled },
            set: { toggleOpenAtLogin($0) }
        )
    }
}

private struct PetConfigurationPane: View {
    @ObservedObject var store: PetStore
    let respawnSelectedPet: () -> Void
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PetInstanceCarouselView(store: store)

            if let selectedPet {
                selectedPetHeader(for: selectedPet)

                VStack(spacing: 14) {
                    SpriteSummaryPanel(
                        pet: selectedPet,
                        dominantStatus: store.dominantStatus
                    )

                    HStack(alignment: .top, spacing: 14) {
                        BehaviorSettingsPanel(store: store)
                            .frame(maxWidth: .infinity, alignment: .top)

                        PetDetailsSettingsPanel(store: store)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            } else {
                EmptyPetCollectionView {
                    store.addPet()
                }
            }
        }
        .padding(22)
        .background(SettingsDesignPalette.root)
        .confirmationDialog(
            "Delete \(selectedPet?.name ?? "Pet")?",
            isPresented: $isDeleteConfirmationPresented
        ) {
            Button("Delete Pet", role: .destructive) {
                store.removeSelectedPet()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected pet from your collection.")
        }
    }

    private var selectedPet: PetInstance? {
        store.selectedPetInstance
    }

    private func selectedPetHeader(for selectedPet: PetInstance) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPet.name)
                    .font(.title2.bold())

                Text("\(selectedPet.isVisible ? "Visible" : "Hidden") - \(petFamilyName(for: selectedPet.petID)) - active session aware")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Respawn") {
                respawnSelectedPet()
            }
            .buttonStyle(.borderedProminent)
            .tint(SettingsDesignPalette.accentStrong)

            Button(selectedPet.isVisible ? "Hide" : "Show") {
                store.updatePetVisibility(selectedPet.id, isVisible: !selectedPet.isVisible)
            }

            Button("Duplicate") {
                store.duplicateSelectedPet()
            }

            Button("Delete", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
        }
    }

    private func petFamilyName(for petID: PetID) -> String {
        PetCatalog.category(for: petID)?.displayName ?? "Custom Pet"
    }
}

private struct EmptyPetCollectionView: View {
    let addPet: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(SettingsDesignPalette.accent)

            Text("No Pets")
                .font(.title2.bold())

            Text("Add a pet when you want one on your desktop.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                addPet()
            } label: {
                Label("Add Pet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(SettingsDesignPalette.accentStrong)
        }
        .frame(maxWidth: .infinity, minHeight: 366)
        .background(SettingsDesignPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsDesignPalette.border)
        }
    }
}

private struct PetInstanceCarouselView: View {
    @ObservedObject var store: PetStore

    var body: some View {
        GeometryReader { proxy in
            let carouselContentWidth = carouselContentWidth
            let isOverflowing = carouselContentWidth > proxy.size.width

            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.petInstances) { pet in
                            PetCarouselCard(
                                pet: pet,
                                isSelected: pet.id == store.selectedPetInstanceID
                            ) {
                                store.selectPetInstance(pet.id)
                            }
                        }

                        Button {
                            store.addPet()
                        } label: {
                            Label("Add Pet", systemImage: "plus")
                                .frame(width: 104, height: 58)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 12)
                }

                if isOverflowing {
                    HStack {
                        PetCarouselArrow(systemName: "chevron.left")
                        Spacer()
                        PetCarouselArrow(systemName: "chevron.right")
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 92)
        .background(SettingsDesignPalette.panelRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(SettingsDesignPalette.border)
        }
    }

    private var carouselContentWidth: CGFloat {
        let petCount = CGFloat(store.petInstances.count)
        let itemCount = petCount + 1
        let gapCount = max(0, itemCount - 1)
        return (petCount * 198) + 104 + (gapCount * 10) + 96
    }
}

private struct PetCarouselArrow: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(SettingsDesignPalette.accent)
            .frame(width: 32, height: 42)
            .background(SettingsDesignPalette.inset.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 9)
    }
}

private struct PetCarouselCard: View {
    let pet: PetInstance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(0.08))

                    PetSprite(
                        petID: pet.petID,
                        visualContext: PetVisualContext(
                            status: .idle,
                            hasActiveSessions: true,
                            isHovered: false,
                            animationSettings: pet.animationSettings
                        ),
                        pixelation: pet.pixelation
                    )
                    .frame(width: 34, height: 34)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(carouselSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 124, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(width: 198, height: 58)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? SettingsDesignPalette.selectedFill : Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? SettingsDesignPalette.accent.opacity(0.65) : Color.clear, lineWidth: 1)
        }
    }

    private var carouselSubtitle: String {
        PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
    }
}

private struct PetCarouselFade: View {
    enum Edge {
        case leading
        case trailing
    }

    let edge: Edge

    var body: some View {
        LinearGradient(
            colors: edge == .leading
                ? [Color(nsColor: .windowBackgroundColor), Color(nsColor: .windowBackgroundColor).opacity(0)]
                : [Color(nsColor: .windowBackgroundColor).opacity(0), Color(nsColor: .windowBackgroundColor)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 40)
    }
}

private struct SpriteSummaryPanel: View {
    let pet: PetInstance
    let dominantStatus: HarnessSessionStatus

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(SettingsDesignPalette.inset)

                SpritePreviewGridBackground()

                PetSprite(
                    petID: pet.petID,
                    visualContext: PetVisualContext(
                        status: dominantStatus,
                        hasActiveSessions: dominantStatus != .unknown,
                        isHovered: false,
                        animationSettings: pet.animationSettings
                    ),
                    pixelation: pet.pixelation
                )
                .frame(width: 112, height: 112)
            }
            .frame(maxWidth: .infinity, minHeight: 218)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SettingsDesignPalette.border)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Sprite")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Generated Cute Cloud")
                    .font(.title3.bold())

                Text("The only built-in pet, with generated artwork for every activity state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    SpriteCapabilityTag(petFamilyName)
                    SpriteCapabilityTag(pet.pixelation.displayName)
                    if PetCatalog.definition(for: pet.petID)?.capabilities.supportsStatusMoods == true {
                        SpriteCapabilityTag("Moods")
                    }
                }

            }
            .frame(width: 260, alignment: .leading)
        }
        .padding(16)
        .background(SettingsDesignPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsDesignPalette.border)
        }
    }

    private var petFamilyName: String {
        PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
    }
}

private struct SpritePreviewGridBackground: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 18

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(Color.white.opacity(0.045)), lineWidth: 1)
        }
        .padding(16)
    }
}

private struct SpriteCapabilityTag: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct BehaviorSettingsPanel: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Behavior")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            SettingSwitchRow("Hover bounce", isOn: animationBinding(\.isHoverBounceEnabled))
            SettingSwitchRow("Idle motion", isOn: animationBinding(\.isIdleMotionEnabled))
            SettingSwitchRow("Status moods", isOn: animationBinding(\.areStatusMoodsEnabled))

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(SettingsDesignPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsDesignPalette.border)
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
}

private struct SettingSwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(GradientSettingsToggleStyle())
        }
    }
}

private struct GradientSettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackFill(isOn: configuration.isOn))

                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: Color.black.opacity(0.28), radius: 3, x: 0, y: 2)
                    .padding(3)
            }
            .frame(width: 42, height: 24)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }

    private func trackFill(isOn: Bool) -> AnyShapeStyle {
        if isOn {
            return AnyShapeStyle(
                LinearGradient(colors: [SettingsDesignPalette.switchPink, SettingsDesignPalette.switchTeal],
                               startPoint: .leading,
                               endPoint: .trailing)
            )
        }

        return AnyShapeStyle(Color.white.opacity(0.12))
    }
}

private struct PetDetailsSettingsPanel: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pet Details")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name")
                        .foregroundStyle(.secondary)
                    TextField("", text: nameBinding)
                        .accessibilityLabel("Name")
                }

                GridRow {
                    Text("Style")
                        .foregroundStyle(.secondary)
                    Picker("Pixelation", selection: pixelationBinding) {
                        ForEach(PetSpritePixelation.allCases, id: \.self) { pixelation in
                            Text(pixelation.displayName)
                                .tag(pixelation)
                                .disabled(pixelation > PetCatalog.maximumPixelation(for: selectedPet.petID))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                }

                GridRow {
                    Text("Context")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Slider(
                            value: contextLineCountSliderBinding,
                            in: contextLineCountSliderRange,
                            step: 1
                        )

                        Text("\(selectedPet.sessionContextLineCount)")
                            .monospacedDigit()
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(SettingsDesignPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(SettingsDesignPalette.border)
        }
    }

    private var selectedPet: PetInstance {
        store.selectedPetInstance ?? PetInstance.defaultInstance()
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { store.selectedPetInstance?.name ?? "" },
            set: { store.updateSelectedPetName($0) }
        )
    }

    private var pixelationBinding: Binding<PetSpritePixelation> {
        Binding(
            get: { store.selectedPetInstance?.pixelation ?? .off },
            set: { store.updateSelectedPetPixelation($0) }
        )
    }

    private var contextLineCountSliderBinding: Binding<Double> {
        Binding(
            get: { Double(store.selectedPetInstance?.sessionContextLineCount ?? PetSessionContextLineCount.defaultValue) },
            set: { store.updateSelectedPetContextLineCount(Int($0.rounded())) }
        )
    }

    private var contextLineCountSliderRange: ClosedRange<Double> {
        Double(PetSessionContextLineCount.supportedRange.lowerBound)...Double(PetSessionContextLineCount.supportedRange.upperBound)
    }
}
