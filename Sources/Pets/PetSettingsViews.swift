import AppKit
import SwiftUI
import PetsCore

private enum PetSettingsTab: Hashable {
    case pets
    case collection
}

struct PetSettingsView: View {
    @ObservedObject var store: PetStore
    @ObservedObject var updateController: PetUpdateController
    let respawnPet: (PetInstance.ID) -> Void
    @State private var selectedTab = PetSettingsTab.pets
    @State private var isPetPickerPresented = false

    var body: some View {
        Group {
            switch selectedTab {
            case .pets:
                PetConfigurationPane(
                    store: store,
                    respawnPet: respawnPet,
                    isPetPickerPresented: $isPetPickerPresented
                )
            case .collection:
                PetCollectionView(store: store)
            }
        }
        .frame(width: 900, height: 620)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let release = updateController.availableRelease {
                PetUpdateBanner(
                    release: release,
                    openRelease: updateController.openAvailableRelease
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Settings Section", selection: $selectedTab) {
                    Label("Pets", systemImage: "pawprint")
                        .tag(PetSettingsTab.pets)
                    Label("Collection", systemImage: "square.grid.2x2")
                        .tag(PetSettingsTab.collection)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(isPetPickerPresented)
            }
        }
    }
}

private struct PetUpdateBanner: View {
    let release: PetsRelease
    let openRelease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pets \(release.displayVersion) is available")
                    .font(.headline)
                Text("Download it from GitHub and replace the app. Your pets and preferences will stay in place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button("View on GitHub", action: openRelease)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.10))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct PetConfigurationPane: View {
    @ObservedObject var store: PetStore
    let respawnPet: (PetInstance.ID) -> Void
    @Binding var isPetPickerPresented: Bool
    @State private var petPendingDeletionID: PetInstance.ID?

    var body: some View {
        ZStack {
            NavigationSplitView {
                PetSidebar(
                    store: store,
                    respawnPet: respawnPet
                )
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
            } detail: {
                Group {
                    if let selectedPet {
                        PetDetailPane(
                            store: store,
                            pet: selectedPet,
                            respawnPet: { respawnPet(selectedPet.id) },
                            changePet: { isPetPickerPresented = true },
                            deletePet: { petPendingDeletionID = selectedPet.id }
                        )
                    } else {
                        EmptyPetCollectionView {
                            store.addPet()
                        }
                    }
                }
            }

            if isPetPickerPresented {
                PetPickerOverlay(
                    store: store,
                    isPresented: $isPetPickerPresented
                )
            }
        }
        .confirmationDialog(
            "Delete \(petPendingDeletion?.name ?? "Pet")?",
            isPresented: isDeleteConfirmationPresented,
            presenting: petPendingDeletion
        ) { pet in
            Button("Delete Pet", role: .destructive) {
                store.removePet(pet.id)
                petPendingDeletionID = nil
            }

            Button("Cancel", role: .cancel) {}
        } message: { pet in
            Text("This removes \(pet.name) from your collection.")
        }
    }

    private var selectedPet: PetInstance? {
        store.selectedPetInstance
    }

    private var petPendingDeletion: PetInstance? {
        guard let petPendingDeletionID else { return nil }
        return store.petInstance(for: petPendingDeletionID)
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { petPendingDeletionID != nil },
            set: { isPresented in
                if !isPresented {
                    petPendingDeletionID = nil
                }
            }
        )
    }
}

private struct PetSidebar: View {
    @ObservedObject var store: PetStore
    let respawnPet: (PetInstance.ID) -> Void
    @State private var petBeingRenamedID: PetInstance.ID?
    @State private var renameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectedPetBinding) {
                Section("My Pets") {
                    ForEach(store.petInstances) { pet in
                        PetSidebarRow(
                            pet: pet,
                            isRenaming: petBeingRenamedID == pet.id,
                            renameDraft: $renameDraft,
                            commitRename: { commitRename(pet.id) },
                            cancelRename: { cancelRename(pet.id) }
                        )
                            .tag(pet.id)
                            .contextMenu {
                                Button("Rename") {
                                    beginRenaming(pet)
                                }

                                Divider()

                                Button(pet.isVisible ? "Hide" : "Show") {
                                    store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
                                }

                                Button("Respawn") {
                                    respawnPet(pet.id)
                                }

                                Button("Duplicate") {
                                    store.duplicatePet(pet.id)
                                }

                                Divider()

                                Button("Delete", role: .destructive) {
                                    store.removePet(pet.id)
                                }
                            }
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

    private func beginRenaming(_ pet: PetInstance) {
        store.selectPetInstance(pet.id)
        renameDraft = pet.name
        petBeingRenamedID = pet.id
    }

    private func commitRename(_ id: PetInstance.ID) {
        guard petBeingRenamedID == id else { return }
        store.updatePetName(id, name: renameDraft)
        petBeingRenamedID = nil
        renameDraft = ""
    }

    private func cancelRename(_ id: PetInstance.ID) {
        guard petBeingRenamedID == id else { return }
        petBeingRenamedID = nil
        renameDraft = ""
    }
}

private struct PetSidebarRow: View {
    let pet: PetInstance
    let isRenaming: Bool
    @Binding var renameDraft: String
    let commitRename: () -> Void
    let cancelRename: () -> Void
    @FocusState private var isRenameFieldFocused: Bool
    @State private var isCancellingRename = false

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

            if isRenaming {
                TextField("Pet name", text: $renameDraft)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .focused($isRenameFieldFocused)
                    .onSubmit(commitRename)
                    .onExitCommand {
                        isCancellingRename = true
                        cancelRename()
                    }
                    .onAppear {
                        isCancellingRename = false
                        isRenameFieldFocused = true
                        DispatchQueue.main.async {
                            NSApp.sendAction(
                                #selector(NSText.selectAll(_:)),
                                to: nil,
                                from: nil
                            )
                        }
                    }
                    .onChange(of: isRenameFieldFocused) { _, isFocused in
                        if !isFocused && isRenaming && !isCancellingRename {
                            commitRename()
                        }
                    }
            } else {
                Text(pet.name)
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
    let respawnPet: () -> Void
    let changePet: () -> Void
    let deletePet: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                PetPreview(
                    pet: pet,
                    dominantStatus: store.dominantStatus
                )

                PetDetailsSection(store: store)

                Divider()

                PetAppearanceSection(
                    pet: pet,
                    changePet: changePet
                )

                Divider()

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
                respawnPet()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .controlAccentColor))

            Button(pet.isVisible ? "Hide" : "Show") {
                store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
            }

            Menu {
                Button("Duplicate") {
                    store.duplicatePet(pet.id)
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

private struct FlatSettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PetDetailsSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        FlatSettingsSection("Pet Details") {
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
    let changePet: () -> Void

    var body: some View {
        FlatSettingsSection("Appearance") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(PetCatalog.displayName(for: pet.petID))
                        .font(.body.weight(.medium))

                    Text(spriteDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Change Pet...") {
                    changePet()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var spriteDescription: String {
        let familyName = PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
        return "\(familyName) · \(pet.pixelation.displayName)"
    }
}

private struct PetBehaviorSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        FlatSettingsSection("Behavior") {
            VStack(spacing: 0) {
                SettingSwitchRow("Hover bounce", isOn: animationBinding(\.isHoverBounceEnabled))

                Divider()

                SettingSwitchRow("Idle motion", isOn: animationBinding(\.isIdleMotionEnabled))

                Divider()

                SettingSwitchRow("Status moods", isOn: animationBinding(\.areStatusMoodsEnabled))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .toggleStyle(.switch)
        }
        .padding(.vertical, 6)
    }
}

private struct PetPickerSheet: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose a Pet")
                    .font(.title2.bold())

                Text("Choose a pet from any family you have unlocked.")
                    .foregroundStyle(.secondary)
            }

            Picker("Pet family", selection: $selectedCategoryID) {
                ForEach(PetCatalog.builtInCategories, id: \.id) { category in
                    Text(category.displayName)
                        .tag(Optional(category.id))
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(selectedCategory.petIDs, id: \.self) { petID in
                        PetPickerCard(
                            petID: petID,
                            isSelected: petID == store.selectedPetInstance?.petID,
                            isOwned: store.isPetOwned(petID)
                        ) {
                            store.updateSelectedPetID(petID)
                            isPresented = false
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 820, height: 560)
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

private struct PetPickerOverlay: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }
                .accessibilityHidden(true)

            PetPickerSheet(
                store: store,
                isPresented: $isPresented
            )
            .background {
                Color(nsColor: .windowBackgroundColor)

                PetPickerWindowClickMonitor {
                    isPresented = false
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        }
        .onExitCommand {
            isPresented = false
        }
    }
}

private struct PetPickerWindowClickMonitor: NSViewRepresentable {
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = HitPassthroughView()
        context.coordinator.startMonitoring(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.dismiss = dismiss
        context.coordinator.startMonitoring(view: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    @MainActor
    final class Coordinator {
        var dismiss: () -> Void
        private weak var view: NSView?
        private var eventMonitor: Any?

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func startMonitoring(view: NSView) {
            self.view = view
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                precondition(Thread.isMainThread)
                let eventBox = MainThreadEvent(event)
                let shouldSwallow = MainActor.assumeIsolated {
                    self?.handle(eventBox.value) ?? false
                }
                return shouldSwallow ? nil : event
            }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard let view,
                  event.window === view.window
            else {
                return false
            }

            let pointInPicker = view.convert(event.locationInWindow, from: nil)
            guard !view.bounds.contains(pointInPicker) else {
                return false
            }

            dismiss()
            return true
        }

        func stopMonitoring() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private struct MainThreadEvent: @unchecked Sendable {
        let value: NSEvent

        init(_ value: NSEvent) {
            self.value = value
        }
    }

    private final class HitPassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private struct PetPickerCard: View {
    let petID: PetID
    let isSelected: Bool
    let isOwned: Bool
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

                if !isOwned {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)
        .opacity(isOwned ? 1 : 0.58)
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
