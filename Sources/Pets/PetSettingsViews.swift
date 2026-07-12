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
    }
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
    @State private var isSpritePickerPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        NavigationSplitView {
            PetSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            if let selectedPet {
                PetDetailPane(
                    store: store,
                    pet: selectedPet,
                    respawnSelectedPet: respawnSelectedPet,
                    changeSprite: { isSpritePickerPresented = true },
                    deletePet: { isDeleteConfirmationPresented = true }
                )
            } else {
                EmptyPetCollectionView {
                    store.addPet()
                }
            }
        }
        .sheet(isPresented: $isSpritePickerPresented) {
            SpritePickerSheet(
                store: store,
                isPresented: $isSpritePickerPresented
            )
        }
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
}

private struct PetSidebar: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectedPetBinding) {
                Section("My Pets") {
                    ForEach(store.petInstances) { pet in
                        PetSidebarRow(pet: pet)
                            .tag(pet.id)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button {
                    store.addPet()
                } label: {
                    Label("Add Pet", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Pet")

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var selectedPetBinding: Binding<PetInstance.ID?> {
        Binding(
            get: { store.selectedPetInstanceID },
            set: { selectedID in
                guard let selectedID else { return }
                store.selectPetInstance(selectedID)
            }
        )
    }
}

private struct PetSidebarRow: View {
    let pet: PetInstance

    var body: some View {
        HStack(spacing: 10) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .lineLimit(1)

                Text(pet.isVisible ? "Visible" : "Hidden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct PetDetailPane: View {
    @ObservedObject var store: PetStore
    let pet: PetInstance
    let respawnSelectedPet: () -> Void
    let changeSprite: () -> Void
    let deletePet: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                PetPreview(
                    pet: pet,
                    dominantStatus: store.dominantStatus
                )

                PetDetailsSection(store: store)

                PetAppearanceSection(
                    pet: pet,
                    changeSprite: changeSprite
                )

                PetBehaviorSection(store: store)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
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
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.title2.weight(.semibold))

                Text("\(petFamilyName) · \(pet.isVisible ? "Visible" : "Hidden") · Session aware")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button("Respawn") {
                respawnSelectedPet()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlAccentColor))

            Button(pet.isVisible ? "Hide" : "Show") {
                store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
            }

            Menu {
                Button("Duplicate") {
                    store.duplicateSelectedPet()
                }

                Divider()

                Button("Delete", role: .destructive) {
                    deletePet()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("More pet actions")
            .accessibilityLabel("More pet actions")
        }
    }

    private var petFamilyName: String {
        PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
    }
}

private struct EmptyPetCollectionView: View {
    let addPet: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct PetPreview: View {
    let pet: PetInstance
    let dominantStatus: HarnessSessionStatus

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))

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
            .frame(width: 116, height: 116)
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pet.name) preview")
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

            context.stroke(
                path,
                with: .color(Color(nsColor: .separatorColor).opacity(0.45)),
                lineWidth: 1
            )
        }
        .padding(16)
        .allowsHitTesting(false)
    }
}

private struct PetDetailsSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
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
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Pet Details")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            get: {
                Double(
                    store.selectedPetInstance?.sessionContextLineCount
                        ?? PetSessionContextLineCount.defaultValue
                )
            },
            set: { store.updateSelectedPetContextLineCount(Int($0.rounded())) }
        )
    }

    private var contextLineCountSliderRange: ClosedRange<Double> {
        let lowerBound = Double(PetSessionContextLineCount.supportedRange.lowerBound)
        let upperBound = Double(PetSessionContextLineCount.supportedRange.upperBound)
        return lowerBound...upperBound
    }
}

private struct PetAppearanceSection: View {
    let pet: PetInstance
    let changeSprite: () -> Void

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(PetCatalog.displayName(for: pet.petID))
                        .font(.body.weight(.medium))

                    Text(spriteDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Change Sprite...") {
                    changeSprite()
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Appearance")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spriteDescription: String {
        let familyName = PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
        return "\(familyName) · \(pet.pixelation.displayName)"
    }
}

private struct PetBehaviorSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                SettingSwitchRow("Hover bounce", isOn: animationBinding(\.isHoverBounceEnabled))
                SettingSwitchRow("Idle motion", isOn: animationBinding(\.isIdleMotionEnabled))
                SettingSwitchRow("Status moods", isOn: animationBinding(\.areStatusMoodsEnabled))
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Behavior")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .toggleStyle(.switch)
        }
    }
}

private struct SpritePickerSheet: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose a Cloud")
                    .font(.title2.bold())

                Text("Each cloud has its own silhouette, anatomy, and motion style.")
                    .foregroundStyle(.secondary)
            }

            Picker("Pet family", selection: $selectedCategoryID) {
                ForEach(PetCatalog.builtInCategories, id: \.id) { category in
                    Text(category.displayName)
                        .tag(Optional(category.id))
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(selectedCategory.petIDs, id: \.self) { petID in
                    SpritePickerCard(
                        petID: petID,
                        isSelected: petID == store.selectedPetInstance?.petID
                    ) {
                        store.updateSelectedPetID(petID)
                        isPresented = false
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .padding(22)
        .frame(width: 820, height: 460)
        .onAppear {
            selectedCategoryID = store.selectedPetInstance
                .flatMap { PetCatalog.category(for: $0.petID)?.id }
                ?? selectedCategoryID
        }
    }

    private var selectedCategory: PetCatalogCategory {
        PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
            ?? PetCatalog.builtInCategories[0]
    }
}

private struct SpritePickerCard: View {
    let petID: PetID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary.opacity(0.6))

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
                    .frame(width: 94, height: 94)
                }
                .frame(height: 120)

                Text(PetCatalog.displayName(for: petID))
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
        }
    }
}
