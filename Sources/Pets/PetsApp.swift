import AppKit
import PetsCore
import Combine
import ServiceManagement
import SwiftUI

@main
struct PetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PetSettingsView(
                store: appDelegate.store,
                toggleOpenAtLogin: { isEnabled in
                    appDelegate.setOpenAtLogin(isEnabled)
                },
                respawnSelectedPet: {
                    appDelegate.respawnSelectedPet()
                }
            )
        }

        MenuBarExtra("Pets", systemImage: "pawprint.circle") {
            PetMenuView(
                store: appDelegate.store,
                togglePetVisibility: {
                    appDelegate.togglePetVisibility()
                },
                respawnPet: {
                    appDelegate.respawnPet()
                },
                bringConfigurationToFront: {
                    appDelegate.bringConfigurationToFront()
                }
            )
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panels: [PetInstance.ID: PetPanel] = [:]
    let store = PetStore()
    private var isAdjustingPanelFrame = false
    private var isSyncingPetPanels = false
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.updateOpenAtLoginEnabled(LoginItemController.isEnabled)

        store.$petInstances
            .sink { [weak self] _ in
                self?.syncPetPanels()
            }
            .store(in: &cancellables)
        syncPetPanels()
        store.start()
    }

    func togglePetVisibility() {
        store.setAllPetsVisible(!store.areAnyPetsVisible)
    }

    func respawnPet() {
        respawnVisiblePets()
    }

    func bringConfigurationToFront() {
        NSApp.activate(ignoringOtherApps: true)

        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)

            if let window = NSApp.windows.reversed().first(where: Self.isConfigurationWindow) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    private static func isConfigurationWindow(_ window: NSWindow) -> Bool {
        !(window is PetPanel)
            && window.canBecomeKey
            && window.styleMask.contains(.titled)
            && window.styleMask.contains(.closable)
    }

    func respawnSelectedPet() {
        guard let selectedID = store.selectedPetInstanceID else { return }
        panels[selectedID]?.close()
        panels.removeValue(forKey: selectedID)
        store.updatePetVisibility(selectedID, isVisible: true)
        syncPetPanels()
    }

    func setOpenAtLogin(_ isEnabled: Bool) {
        do {
            try LoginItemController.setEnabled(isEnabled)
            store.updateOpenAtLoginEnabled(LoginItemController.isEnabled)
        } catch {
            store.updateOpenAtLoginEnabled(LoginItemController.isEnabled)
            store.recordError(error.localizedDescription)
        }
    }

    private func makePanel(for petInstance: PetInstance, index: Int) -> PetPanel {
        let panel = PetPanel(
            contentRect: Self.initialFrame(for: petInstance, index: index),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.petInstanceID = petInstance.id
        panel.contentView = FirstMouseHostingView(
            rootView: PetOverlayView(store: store, petInstanceID: petInstance.id)
        )
        panel.delegate = self
        return panel
    }

    private func syncPetPanels() {
        guard !isSyncingPetPanels else { return }
        isSyncingPetPanels = true
        defer { isSyncingPetPanels = false }

        let visibleInstances = store.visiblePetInstances
        let visibleIDs = Set(visibleInstances.map(\.id))

        let staleIDs = panels.keys.filter { !visibleIDs.contains($0) }
        for id in staleIDs {
            panels[id]?.close()
            panels.removeValue(forKey: id)
        }

        for (index, petInstance) in visibleInstances.enumerated() {
            if let panel = panels[petInstance.id] {
                panel.orderFrontRegardless()
                updateOverlayPlacement(for: panel)
            } else {
                let panel = makePanel(for: petInstance, index: index)
                panels[petInstance.id] = panel
                panel.orderFrontRegardless()
                updateOverlayPlacement(for: panel)
            }
        }
    }

    private func respawnVisiblePets() {
        for panel in panels.values {
            panel.close()
        }
        panels.removeAll()
        syncPetPanels()
    }

    private static func initialFrame(for petInstance: PetInstance, index: Int) -> NSRect {
        let size = NSSize(width: 500, height: 360)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if let origin = petInstance.overlayPosition.origin {
            return NSRect(origin: origin, size: size)
        }

        return NSRect(
            x: screenFrame.maxX - size.width - 28,
            y: screenFrame.minY + 42 + CGFloat(index * 28),
            width: size.width,
            height: size.height
        )
    }

    private func updateOverlayPlacement(for panel: NSPanel) {
        guard !isAdjustingPanelFrame else { return }
        guard let panel = panel as? PetPanel, let petInstanceID = panel.petInstanceID else { return }

        let visibleFrame = panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        guard let petInstance = store.petInstance(for: petInstanceID) else { return }
        let placement = PetOverlayHorizontalPlacement.preferred(
            for: panel.frame,
            in: visibleFrame,
            current: petInstance.overlayPosition.horizontalPlacement
        )

        let adjustedFrame = PetOverlayHorizontalPlacement.adjustedPanelFrame(
            panel.frame,
            in: visibleFrame
        )

        if adjustedFrame != panel.frame {
            isAdjustingPanelFrame = true
            panel.setFrame(adjustedFrame, display: true)
            isAdjustingPanelFrame = false
        }

        store.updatePetOverlayPosition(
            petInstanceID,
            origin: adjustedFrame.origin,
            placement: placement
        )
    }
}

private struct PetMenuView: View {
    @Environment(\.openSettings) private var openSettings

    @ObservedObject var store: PetStore
    let togglePetVisibility: () -> Void
    let respawnPet: () -> Void
    let bringConfigurationToFront: () -> Void

    var body: some View {
        Button("Respawn Pet") {
            respawnPet()
        }
        .disabled(store.petInstances.isEmpty)

        Button(store.areAnyPetsVisible ? "Hide Pet" : "Show Pet") {
            togglePetVisibility()
        }
        .disabled(store.petInstances.isEmpty)

        Button {
            openSettings()
            bringConfigurationToFront()
        } label: {
            Label("Configure...", systemImage: "slider.horizontal.3")
        }

        Divider()

        Button("Quit Pets") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct PetSettingsView: View {
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
    @State private var isSpritePickerPresented = false
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
                    ) {
                        isSpritePickerPresented = true
                    }

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
                        status: .unknown,
                        isExcited: false,
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
    let dominantStatus: ClaudeDisplayStatus
    let changeSprite: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(SettingsDesignPalette.inset)

                SpritePreviewGridBackground()

                PetSprite(
                    petID: pet.petID,
                    status: pet.animationSettings.areStatusMoodsEnabled ? dominantStatus : .unknown,
                    isExcited: false,
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

                Text(PetCatalog.displayName(for: pet.petID))
                    .font(.title3.bold())

                Text("Current sprite in \(petFamilyName). Open the picker to switch variants or choose another family.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    SpriteCapabilityTag(petFamilyName)
                    SpriteCapabilityTag(pet.pixelation.displayName)
                    SpriteCapabilityTag("Moods")
                }

                Button("Change Sprite...") {
                    changeSprite()
                }
                .buttonStyle(.borderedProminent)
                .tint(SettingsDesignPalette.accentStrong)
                .padding(.top, 2)
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

private struct SpritePickerSheet: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose a Sprite")
                        .font(.title2.bold())

                    Text("Preview every available sprite before applying one.")
                        .foregroundStyle(.secondary)
                }

                Spacer()
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
        .frame(width: 680, height: 520)
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
                        status: .unknown,
                        isExcited: false,
                        pixelation: .off
                    )
                    .frame(width: 86, height: 86)
                }
                .frame(height: 116)

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
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
        }
    }
}

private enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        updateOverlayPlacement(for: panel)
    }
}

final class PetPanel: NSPanel {
    var petInstanceID: PetInstance.ID?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureTransparentBackground()
    }

    @MainActor
    required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTransparentBackground()
    }

    override var isOpaque: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hitView = super.hitTest(point) {
            return hitView
        }

        if descendantScrollView(at: point) != nil {
            return self
        }

        return nil
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let scrollView = descendantScrollView(at: point) else {
            super.scrollWheel(with: event)
            return
        }

        scrollView.scrollWheel(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparentBackground()
    }

    private func configureTransparentBackground() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    private func descendantScrollView(at point: NSPoint) -> NSScrollView? {
        descendantScrollView(in: self, containing: point)
    }

    private func descendantScrollView(in view: NSView, containing pointInSelf: NSPoint) -> NSScrollView? {
        for subview in view.subviews.reversed() {
            guard !subview.isHidden, subview.alphaValue > 0 else { continue }

            if let scrollView = subview as? NSScrollView {
                let pointInScrollView = scrollView.convert(pointInSelf, from: self)
                if scrollView.bounds.contains(pointInScrollView) {
                    return scrollView
                }
            }

            if let scrollView = descendantScrollView(in: subview, containing: pointInSelf) {
                return scrollView
            }
        }

        return nil
    }
}
