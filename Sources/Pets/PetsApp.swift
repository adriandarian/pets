import AppKit
import PetsCore
import Combine
import ServiceManagement
import SwiftUI

private enum PetsWindowID {
    static let configuration = "configuration"
#if PETS_DEVELOPMENT
    static let configurationTitle = "Pets Dev"
#else
    static let configurationTitle = "Pets"
#endif
}

@main
struct PetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window(PetsWindowID.configurationTitle, id: PetsWindowID.configuration) {
            PetSettingsView(
                store: appDelegate.store,
                updateController: appDelegate.updateController,
                respawnPet: { petID in
                    appDelegate.respawnPet(petID)
                }
            )
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            PetMenuView(
                store: appDelegate.store,
                updateController: appDelegate.updateController,
                setAllPetsVisible: { isVisible in
                    appDelegate.setAllPetsVisible(isVisible)
                },
                respawnPet: {
                    appDelegate.respawnPet()
                },
                bringConfigurationToFront: {
                    appDelegate.bringConfigurationToFront()
                }
            )
        } label: {
            PetMenuBarLabel(updateController: appDelegate.updateController)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panels: [PetInstance.ID: PetPanel] = [:]
    let store = PetStore()
    let updateController = PetUpdateController()
    private var isAdjustingPanelFrame = false
    private var isSyncingPetPanels = false
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        disableLegacyOpenAtLogin()

        store.$petInstances
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await Task.yield()
                    self?.syncPetPanels()
                }
            }
            .store(in: &cancellables)
        syncPetPanels()
        store.start()
        updateController.start()
        presentReleaseGiftIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func disableLegacyOpenAtLogin() {
        let status = SMAppService.mainApp.status
        guard status == .enabled || status == .requiresApproval else { return }

        do {
            try SMAppService.mainApp.unregister()
        } catch {
            store.recordError(error.localizedDescription)
        }
    }

    private func presentReleaseGiftIfNeeded() {
        guard let gift = store.pendingReleaseGift else { return }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.store.pendingReleaseGift == gift else { return }

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "A gift arrived with Pets \(gift.version)"
            alert.informativeText = "\(Self.releaseGiftDescription(gift)) has been added to your Collection."
            alert.alertStyle = .informational
            alert.icon = NSImage(systemSymbolName: "gift.fill", accessibilityDescription: "Update gift")
            alert.addButton(withTitle: "Nice!")
            alert.runModal()
            self.store.dismissReleaseGift()
        }
    }

    private static func releaseGiftDescription(_ gift: PetReleaseGift) -> String {
        let keys = gift.keyInventory
        if keys.count(for: .rare) == 1 {
            return "1 Rare Key"
        }

        let commonKeys = keys.count(for: .common)
        return "\(commonKeys) Common \(commonKeys == 1 ? "Key" : "Keys")"
    }

    func setAllPetsVisible(_ isVisible: Bool) {
        store.setAllPetsVisible(isVisible)
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

    func respawnPet(_ id: PetInstance.ID) {
        guard store.petInstance(for: id) != nil else { return }
        panels[id]?.close()
        panels.removeValue(forKey: id)
        store.updatePetVisibility(id, isVisible: true)
        syncPetPanels()
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
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var store: PetStore
    @ObservedObject var updateController: PetUpdateController
    let setAllPetsVisible: (Bool) -> Void
    let respawnPet: () -> Void
    let bringConfigurationToFront: () -> Void

    var body: some View {
        if let release = updateController.availableRelease {
            Button {
                updateController.openAvailableRelease()
            } label: {
                Label("Update to \(release.displayVersion)…", systemImage: "arrow.down.circle")
            }

            Divider()
        }

        Button("Respawn Pet") {
            respawnPet()
        }
        .disabled(store.petInstances.isEmpty)

        Button(store.areAnyPetsVisible ? "Hide Pets" : "Show Pets") {
            setAllPetsVisible(!store.areAnyPetsVisible)
        }
        .disabled(store.petInstances.isEmpty)

        Button {
            openWindow(id: PetsWindowID.configuration)
            bringConfigurationToFront()
        } label: {
            Label("Configure...", systemImage: "slider.horizontal.3")
        }

        Divider()

        Button("Check for Updates…") {
            updateController.checkForUpdates(showingResult: true)
        }
        .disabled(updateController.isChecking)

        Button("Quit Pets") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct PetMenuBarLabel: View {
    @ObservedObject var updateController: PetUpdateController

    var body: some View {
#if PETS_DEVELOPMENT
        Label("Pets Dev", systemImage: "hammer.circle")
#else
        Label(
            "Pets",
            systemImage: updateController.availableRelease == nil
                ? "pawprint.circle"
                : "arrow.down.circle"
        )
#endif
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
