import Foundation
import Testing

@Suite
struct PetOverlayTransparencyTests {
    @Test
    func scrollableSessionBubbleDoesNotUseTintedBackgroundForHitTesting() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains(".background(Color.black.opacity("))
    }

    @Test
    func appKitHostingViewRoutesWheelEventsInsideTransparentScrollableGaps() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        #expect(source.contains("override func scrollWheel(with event: NSEvent)"))
        #expect(source.contains("descendantScrollView(at:"))
    }

    @Test
    func scrollableSessionBubbleOverlaysWheelOnlyEventCapture() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains(".overlay(SessionScrollWheelCapture())"))
        #expect(source.contains("NSApp.currentEvent?.type == .scrollWheel"))
        #expect(source.contains("private func scrollView(at windowPoint: NSPoint) -> NSScrollView?"))
    }

    @Test
    func collapsedChatBadgeUsesCompactVisualSize() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("static let collapsedChatBadgeSize: CGFloat = expandedChatControlSize"))
        #expect(source.contains(".frame(width: PetOverlayMetrics.collapsedChatBadgeSize, height: PetOverlayMetrics.collapsedChatBadgeSize)"))
        #expect(!source.contains(".frame(width: 46, height: 46)"))
    }

    @Test
    func collapsedChatBadgeUsesStatusTintInsteadOfAlwaysGreen() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let badgeSource = try #require(source.range(of: "private struct CollapsedChatBadge: View"))
        let nextStruct = try #require(source.range(of: "private struct SessionCardStack", range: badgeSource.upperBound..<source.endIndex))
        let collapsedBadgeSource = String(source[badgeSource.lowerBound..<nextStruct.lowerBound])

        #expect(source.contains("CollapsedChatBadge(count: count, status: status)"))
        #expect(collapsedBadgeSource.contains(".fill(statusColor(status))"))
        #expect(!collapsedBadgeSource.contains(".fill(PetOverlayPalette.codexGreen)"))
    }

    @Test
    func appKitHostingViewIsTransparent() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("override var isOpaque: Bool"))
        #expect(source.contains("layer?.backgroundColor = NSColor.clear.cgColor"))
        #expect(source.contains("layer?.isOpaque = false"))
    }

    @Test
    func inlineReplyEditorUsesReplyLabelAndEscapeToCancel() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let rowStart = try #require(source.range(of: "private struct SessionRow: View"))
        let rowEnd = try #require(source.range(of: "private struct SessionBubbleTopHighlight", range: rowStart.upperBound..<source.endIndex))
        let rowSource = String(source[rowStart.lowerBound..<rowEnd.lowerBound])

        #expect(rowSource.contains("Button(\"Reply\")"))
        #expect(!rowSource.contains("Button(\"Send\")"))
        #expect(!rowSource.contains("isReplying ? \"Cancel\" : \"Reply\""))
        #expect(rowSource.contains(".onExitCommand(perform: cancelReply)"))
    }

    @Test
    func appDefinesMenuBarExtraForPetControls() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("MenuBarExtra {"))
        #expect(source.contains("PetMenuBarLabel(updateController:"))
        #expect(source.contains("\"pawprint.circle\""))
        #expect(source.contains(".menuBarExtraStyle(.menu)"))
        #expect(source.contains("PetMenuView("))
    }

    @Test
    func petInstanceChangesSynchronizePanelsAfterPublishedStateCommits() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let subscriptionStart = try #require(source.range(of: "store.$petInstances"))
        let subscriptionEnd = try #require(
            source.range(
                of: ".store(in: &cancellables)",
                range: subscriptionStart.upperBound..<source.endIndex
            )
        )
        let subscription = String(source[subscriptionStart.lowerBound..<subscriptionEnd.upperBound])

        #expect(subscription.contains("Task { @MainActor [weak self] in"))
        #expect(subscription.contains("await Task.yield()"))
        #expect(subscription.contains("self?.syncPetPanels()"))
    }

    @Test
    func menuLinksToPetConfigurationAndFutureCreationSurface() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let settingsSource = try [
            "Sources/Pets/PetSettingsViews.swift",
            "Sources/Pets/PetDetailViews.swift",
            "Sources/Pets/PetPickerViews.swift"
        ].map { path in
            try String(contentsOf: sourceFile(path), encoding: .utf8)
        }.joined(separator: "\n")

        #expect(source.contains("Window(PetsWindowID.configurationTitle, id: PetsWindowID.configuration)"))
        #expect(source.contains("static let configurationTitle = \"Pets\""))
        #expect(source.contains("@Environment(\\.openWindow)"))
        #expect(source.contains("openWindow(id: PetsWindowID.configuration)"))
        #expect(!source.contains("Settings {"))
        #expect(!source.contains("@Environment(\\.openSettings)"))
        #expect(!source.contains("openSettings()"))
        #expect(source.contains("bringConfigurationToFront()"))
        #expect(source.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(source.contains("first(where: Self.isConfigurationWindow)"))
        #expect(source.contains("window.styleMask.contains(.titled)"))
        #expect(source.contains("window.styleMask.contains(.closable)"))
        #expect(!source.contains("for window in NSApp.windows where !(window is PetPanel)"))
        #expect(source.contains("PetSettingsView("))
        #expect(source.contains("func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {\n        false\n    }"))
        #expect(source.contains("disableLegacyOpenAtLogin()"))
        #expect(source.contains("try SMAppService.mainApp.unregister()"))
        #expect(!source.contains("SMAppService.mainApp.register()"))
        #expect(!source.contains("LoginItemController"))
        #expect(!settingsSource.contains("GeneralSettingsPane"))
        #expect(!settingsSource.contains("Open at Login"))
        #expect(!settingsSource.contains("case general"))
        #expect(!settingsSource.contains("Label(\"General\""))
        #expect(settingsSource.contains("Text(PetCatalog.displayName(for: petID))"))
        #expect(settingsSource.contains("PetCatalog.builtInCategories"))
        #expect(!source.contains("PetConfigurationRow"))
    }

    @Test
    func menuKeepsOnlyTopLevelPetCommands() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Button(\"Respawn Pet\")"))
        #expect(source.contains("\"Hide Pets\" : \"Show Pets\""))
        #expect(source.contains("setAllPetsVisible(!store.areAnyPetsVisible)"))
        #expect(source.contains("func setAllPetsVisible(_ isVisible: Bool)"))
        #expect(source.contains("store.setAllPetsVisible(isVisible)"))
        #expect(source.contains("Label(\"Configure...\", systemImage: \"slider.horizontal.3\")"))
        #expect(source.contains("Button(\"Quit Pets\")"))

        let menuStart = try #require(source.range(of: "private struct PetMenuView: View"))
        let menuEnd = try #require(source.range(of: "extension AppDelegate: NSWindowDelegate", range: menuStart.upperBound..<source.endIndex))
        let menuSource = String(source[menuStart.lowerBound..<menuEnd.lowerBound])

        #expect(!menuSource.contains("Toggle(\"Open at Login\""))
        #expect(!menuSource.contains("Section(\"Sprite\")"))
        #expect(!menuSource.contains("Section(\"Pixelation\")"))
        #expect(!menuSource.contains("Section(\"Context Lines\")"))
    }

    @Test
    func overlayPassesPixelationPreferenceToSprite() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let spritesSourceURL = try sourceFile("Sources/Pets/PetSprites.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let spritesSource = try String(contentsOf: spritesSourceURL, encoding: .utf8)

        #expect(source.contains("PetSprite("))
        #expect(source.contains("PetVisualContext("))
        #expect(source.contains("status: store.dominantStatus(for: petInstance.id)"))
        #expect(source.contains("hasActiveSessions: !store.visibleSessions(for: petInstance.id).isEmpty"))
        #expect(!source.contains("status: spriteStatus"))
        #expect(source.contains("pixelation: petInstance.pixelation"))
        #expect(source.contains(".id(petInstance.pixelation)"))
        #expect(spritesSource.contains("pixelatedSpriteEffect"))
        #expect(spritesSource.contains("PixelatedSpriteRasterizer(pixelation: pixelation)"))
        #expect(spritesSource.contains("imageLayer.magnificationFilter = .nearest"))
        #expect(spritesSource.contains("bitmapImageRepForCachingDisplay"))
        #expect(!spritesSource.contains("PixelatedSpriteOverlay"))
    }

    @Test
    func menuAndOverlayExposeSessionContextLineCount() throws {
        let appSourceURL = try sourceFile("Sources/Pets/PetDetailViews.swift")
        let overlaySourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let appSource = try String(contentsOf: appSourceURL, encoding: .utf8)
        let overlaySource = try String(contentsOf: overlaySourceURL, encoding: .utf8)

        #expect(appSource.contains("Text(\"Session preview\")"))
        #expect(appSource.contains("Text(\"Lines shown in each session bubble\")"))
        #expect(appSource.contains("PetSessionContextLineCount.supportedRange"))
        #expect(appSource.contains("Slider("))
        #expect(appSource.contains("step: 1"))
        #expect(appSource.contains("contextLineCountSliderBinding"))
        #expect(appSource.contains("store.updateSelectedPetContextLineCount"))
        #expect(!appSource.contains("Text(\"Context\")"))
        #expect(!appSource.contains("Picker(\"Context Lines\""))
        #expect(overlaySource.contains("contextLineCount: petInstance.sessionContextLineCount"))
        #expect(overlaySource.contains(".lineLimit(contextLineCount)"))
        #expect(!overlaySource.contains(".lineLimit(2)"))
    }

    @Test
    func petSettingsUseNativeAdaptiveSidebarAndDetailLayout() throws {
        let settings = try String(
            contentsOf: sourceFile("Sources/Pets/PetSettingsViews.swift"),
            encoding: .utf8
        )
        let configuration = try String(
            contentsOf: sourceFile("Sources/Pets/PetConfigurationViews.swift"),
            encoding: .utf8
        )
        let sidebar = try String(
            contentsOf: sourceFile("Sources/Pets/PetSidebarViews.swift"),
            encoding: .utf8
        )
        let detail = try String(
            contentsOf: sourceFile("Sources/Pets/PetDetailViews.swift"),
            encoding: .utf8
        )
        let sections = try String(
            contentsOf: sourceFile("Sources/Pets/PetSettingsSections.swift"),
            encoding: .utf8
        )
        let outsideClickMonitor = try String(
            contentsOf: sourceFile("Sources/Pets/PetWindowOutsideClickMonitor.swift"),
            encoding: .utf8
        )

        #expect(settings.contains("ToolbarItem(placement: .principal)"))
        #expect(settings.contains("if #available(macOS 26.0, *)"))
        #expect(settings.contains(".sharedBackgroundVisibility(.hidden)"))
        #expect(settings.contains("PetSettingsDestination.allCases"))
        #expect(settings.contains("case chests"))
        #expect(settings.contains(".frame(minWidth: 900, minHeight: 620)"))
        #expect(configuration.contains("NavigationSplitView {"))
        #expect(sidebar.contains("List(selection: selectedPetBinding)"))
        #expect(sidebar.contains(".listStyle(.sidebar)"))
        #expect(detail.contains("HStack(alignment: .top, spacing: 28)"))
        #expect(!detail.contains("ScrollView(.vertical"))
        #expect(detail.contains("ViewThatFits(in: .horizontal)"))
        #expect(detail.contains("navigation(showsTitles: false)"))
        #expect(detail.contains(".buttonStyle(.plain)"))
        #expect(!detail.contains(".background(Color.accentColor"))
        #expect(detail.contains("ScrollView(.horizontal, showsIndicators: false)"))
        #expect(detail.contains("Text(\"Session preview\")"))
        #expect(detail.contains("Text(\"Lines shown in each session bubble\")"))
        #expect(detail.contains("Slider("))
        #expect(detail.contains("Button(\"Respawn\")"))
        #expect(detail.contains("Button(pet.isVisible ? \"Hide\" : \"Show\")"))
        #expect(detail.contains("Button(\"Duplicate\")"))
        #expect(detail.contains("Button(\"Delete\", role: .destructive)"))
        #expect(detail.contains("Image(systemName: \"arrow.triangle.2.circlepath\")"))
        #expect(detail.contains("Image(systemName: \"pawprint.fill\")"))
        #expect(detail.contains(".help(\"Change Pet\")"))
        #expect(detail.contains("Image(systemName: \"arrow.down.left.and.arrow.up.right\")"))
        #expect(detail.contains(".help(\"Expand preview\")"))
        #expect(detail.contains(".sheet(isPresented: $isExpandedPreviewPresented)"))
        #expect(detail.contains("PetWindowOutsideClickMonitor { dismiss() }"))
        #expect(detail.contains(".onExitCommand { dismiss() }"))
        #expect(detail.contains(".keyboardShortcut(.cancelAction)"))
        #expect(outsideClickMonitor.contains("event.window !== monitoredWindow"))
        #expect(outsideClickMonitor.contains("dismiss()"))
        #expect(!detail.contains("Button(\"Change Pet...\")"))
        #expect(configuration.contains("Button(\"Delete Pet\", role: .destructive)"))
        #expect(sections.contains("SettingSwitchRow(\"Hover bounce\""))
        #expect(sections.contains(".toggleStyle(.switch)"))
    }

    @Test
    func petSidebarSelectionUsesStoreAsSourceOfTruth() throws {
        let sidebar = try String(
            contentsOf: sourceFile("Sources/Pets/PetSidebarViews.swift"),
            encoding: .utf8
        )
        let configuration = try String(
            contentsOf: sourceFile("Sources/Pets/PetConfigurationViews.swift"),
            encoding: .utf8
        )

        #expect(sidebar.contains("get: { store.selectedPetInstanceID }"))
        #expect(sidebar.contains("store.selectPetInstance(selectedID)"))
        #expect(sidebar.contains("ForEach(store.petInstances)"))
        #expect(sidebar.contains("PetSidebarRow("))
        #expect(sidebar.contains("pet: pet,"))
        #expect(sidebar.contains("store.addPet()"))
        #expect(configuration.contains("PetSidebar(store: store"))
        #expect(!sidebar.contains("PetCarouselArrow"))
    }

    @Test
    func petSidebarContextMenuTargetsTheClickedPet() throws {
        let sidebarSourceURL = try sourceFile("Sources/Pets/PetSidebarViews.swift")
        let configurationSourceURL = try sourceFile("Sources/Pets/PetConfigurationViews.swift")
        let storeSourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let appSourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let sidebarSource = try String(contentsOf: sidebarSourceURL, encoding: .utf8)
        let configurationSource = try String(contentsOf: configurationSourceURL, encoding: .utf8)
        let storeSource = try String(contentsOf: storeSourceURL, encoding: .utf8)
        let appSource = try String(contentsOf: appSourceURL, encoding: .utf8)
        #expect(sidebarSource.contains(".contextMenu"))
        #expect(sidebarSource.contains("Button(pet.isVisible ? \"Hide\" : \"Show\")"))
        #expect(sidebarSource.contains("respawnPet(pet.id)"))
        #expect(sidebarSource.contains("store.duplicatePet(pet.id)"))
        #expect(sidebarSource.contains("store.removePet(pet.id)"))
        #expect(!sidebarSource.contains("deletePet"))
        #expect(configurationSource.contains("@State private var petPendingDeletionID: PetInstance.ID?"))
        #expect(configurationSource.contains("store.removePet(pet.id)"))
        #expect(storeSource.contains("func duplicatePet(_ id: PetInstance.ID)"))
        #expect(storeSource.contains("func removePet(_ id: PetInstance.ID)"))
        #expect(appSource.contains("func respawnPet(_ id: PetInstance.ID)"))
    }

    @Test
    func petSidebarContextMenuSupportsInlineRename() throws {
        let settingsSourceURL = try sourceFile("Sources/Pets/PetSidebarViews.swift")
        let storeSourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let settingsSource = try String(contentsOf: settingsSourceURL, encoding: .utf8)
        let storeSource = try String(contentsOf: storeSourceURL, encoding: .utf8)

        #expect(settingsSource.contains("Button(\"Rename\")"))
        #expect(settingsSource.contains("beginRenaming(pet)"))
        #expect(settingsSource.contains("petBeingRenamedID == pet.id"))
        #expect(settingsSource.contains("TextField(\"Pet name\", text: $renameDraft)"))
        #expect(settingsSource.contains(".onSubmit(commitRename)"))
        #expect(settingsSource.contains(".onExitCommand {"))
        #expect(settingsSource.contains("isCancellingRename = true"))
        #expect(settingsSource.contains(".onChange(of: isRenameFieldFocused)"))
        #expect(settingsSource.contains("#selector(NSText.selectAll(_:))"))
        #expect(settingsSource.contains("store.updatePetName(id, name: renameDraft)"))
        #expect(storeSource.contains("func updatePetName(_ id: PetInstance.ID, name: String)"))
    }

    @Test
    func petSidebarRowDoesNotShowVisibilitySubtext() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetSidebarViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let rowStart = try #require(source.range(of: "private struct PetSidebarRow: View"))
        let rowSource = String(source[rowStart.lowerBound..<source.endIndex])

        #expect(!rowSource.contains("\"Visible\""))
        #expect(!rowSource.contains("\"Hidden\""))
    }

    @Test
    func petSpriteUsesOnlyGeneratedAssetRenderer() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetSprites.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("AssetPetSprite("))
        #expect(source.contains("GeometryReader { proxy in"))
        #expect(!source.contains("LegacyPetSpriteAdapter"))
        #expect(!source.contains("CloudFamilySprite"))
        #expect(!source.contains("VoxelPetSprite"))
    }

    @Test
    func settingsOfferPetSelectionAndBackdropDismissal() throws {
        let source = try [
            "Sources/Pets/PetSettingsViews.swift",
            "Sources/Pets/PetConfigurationViews.swift",
            "Sources/Pets/PetDetailViews.swift",
            "Sources/Pets/PetPickerViews.swift",
            "Sources/Pets/PetWindowOutsideClickMonitor.swift"
        ].map { path in
            try String(contentsOf: sourceFile(path), encoding: .utf8)
        }.joined(separator: "\n")

        #expect(source.contains("PetPickerSheet"))
        #expect(source.contains("PetPickerCard"))
        #expect(source.contains("PetPickerOverlay"))
        #expect(source.contains(".help(\"Change Pet\")"))
        #expect(source.contains("if isPetPickerPresented"))
        #expect(source.contains("isDisabled: isPetPickerPresented"))
        #expect(source.contains("Color.black.opacity(0.42)"))
        #expect(source.contains(".contentShape(Rectangle())"))
        #expect(source.contains(".onTapGesture {"))
        #expect(source.contains("isPresented = false"))
        #expect(source.contains(".onExitCommand {"))
        #expect(source.contains(".keyboardShortcut(.cancelAction)"))
        #expect(source.contains("PetWindowOutsideClickMonitor"))
        #expect(source.contains("NSEvent.addLocalMonitorForEvents"))
        #expect(source.contains("precondition(Thread.isMainThread)"))
        #expect(source.contains("event.window !== monitoredWindow"))
        #expect(source.contains("view.convert(event.locationInWindow, from: nil)"))
        #expect(source.contains("!view.bounds.contains(pointInMonitoredView)"))
        #expect(source.contains("NSEvent.removeMonitor(eventMonitor)"))
        #expect(source.contains("ForEach(PetCatalog.builtInCategories"))
    }

    @Test
    func overlayOffersCloudFamilySwitching() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("ForEach(PetCatalog.builtInPetIDs.filter(store.isPetOwned)"))
        #expect(source.contains("store.selectPet("))
        #expect(source.contains(".contextMenu"))
    }

    @Test
    func petStoreSeedsCumulusOnFirstLaunchButPreservesAnExplicitlyEmptyCollection() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let persistenceSourceURL = try sourceFile("Sources/Pets/PetSettingsPersistence.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let persistenceSource = try String(contentsOf: persistenceSourceURL, encoding: .utf8)

        #expect(persistenceSource.contains("let migrated = PetInstance.migratedDefault("))
        #expect(persistenceSource.contains("return ([migrated], nil)"))
        #expect(persistenceSource.contains("PetTrackerAssignments.normalized("))
        #expect(persistenceSource.contains("decoded.map { $0.normalizedForCurrentCatalog() }"))
        #expect(!source.contains("cloudFamilyCollection(from:"))
        #expect(!source.contains("starterCloudFamilyInstances"))
        #expect(source.contains("@Published private(set) var selectedPetInstanceID: PetInstance.ID?"))
    }

    @Test
    func petStoreDependsOnGenericHarnessBoundary() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("@Published private(set) var sessions: [HarnessSession]"))
        #expect(source.contains("private let harness: any PetHarness"))
        #expect(source.contains("harness: any PetHarness = MultiProviderHarness()"))
        #expect(!source.contains("ClaudeSessionScanner"))
        #expect(!source.contains("ClaudeReplySender"))
        #expect(!source.contains("SessionActivating"))
        #expect(!source.contains("[ClaudeSession]"))
    }

    @Test
    func providerTrackingIsExclusiveConfigurableAndPetScoped() throws {
        let instanceSource = try String(
            contentsOf: sourceFile("Sources/PetsCore/Pets/PetInstance.swift"),
            encoding: .utf8
        )
        let storeSource = try String(
            contentsOf: sourceFile("Sources/Pets/PetStore.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: sourceFile("Sources/Pets/PetSettingsSections.swift"),
            encoding: .utf8
        )
        let overlaySource = try String(
            contentsOf: sourceFile("Sources/Pets/PetOverlayView.swift"),
            encoding: .utf8
        )

        #expect(instanceSource.contains("public var trackingProviders: Set<PetTrackingProvider>"))
        #expect(storeSource.contains("trackingProviders: []"))
        #expect(storeSource.contains("instance.trackingProviders = []"))
        #expect(storeSource.contains("PetTrackerAssignments.setting("))
        #expect(storeSource.contains("func sessions(for petID: PetInstance.ID)"))
        #expect(storeSource.contains("PetSessionRouting.sessions(sessions, trackedBy: pet)"))
        #expect(settingsSource.contains("struct PetTrackingSection: View"))
        #expect(settingsSource.contains("ForEach(Array(PetTrackingProvider.allCases.enumerated())"))
        #expect(settingsSource.contains("Tracked by "))
        #expect(settingsSource.contains("PetProviderIcon(provider: provider"))
        #expect(!settingsSource.contains("provider.sessionDescription"))
        #expect(!settingsSource.contains("Claude Code chats"))
        #expect(!settingsSource.contains("App and CLI tasks"))
        #expect(!settingsSource.contains("CLI and chat sessions"))
        #expect(settingsSource.contains(".disabled(isAssignedElsewhere)"))
        #expect(overlaySource.contains("store.visibleSessions(for: petInstance.id)"))
        #expect(overlaySource.contains("message: \"No trackers assigned\""))
        #expect(overlaySource.contains("session.sourceDisplayName"))
        #expect(storeSource.contains("completionReactionProviderIDs"))
    }

    @Test
    func petStoreCoordinatesCompletionAndErrorReactions() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("@Published private(set) var currentReaction: PetReaction?"))
        #expect(source.contains("private var sessionObservationCoordinator = PetSessionObservationCoordinator()"))
        #expect(source.contains("private static let completionReactionDuration: Duration = .seconds(4)"))
        let sessionObservation = try #require(source.range(
            of: ".observeCompletedHarnessIDs(scannedSessions)"
        ))
        let errorClear = try #require(source.range(
            of: "setLastError(error)",
            range: sessionObservation.upperBound..<source.endIndex
        ))
        #expect(sessionObservation.lowerBound < errorClear.lowerBound)
        #expect(source.contains("private func beginCompletionReaction(for providerIDs: Set<String>)"))
        #expect(source.contains("private func setLastError(_ error: String?)"))
        #expect(source.contains("sessionObservationCoordinator.recordError(error)"))
        #expect(source.contains("completionReactionTask?.cancel()"))
        #expect(source.contains("private var completionReactionExpiry = PetCompletionReactionExpiry()"))
        #expect(source.contains("completionReactionExpiry.cancel()"))
        #expect(source.contains("let generation = completionReactionExpiry.restart()"))
        #expect(source.contains("guard let self, self.currentReaction == .completion else { return }"))
        #expect(source.contains("completionReactionExpiry.invalidate(ifCurrent: generation)"))
        #expect(!source.contains("lastError = error.localizedDescription"))
        #expect(!source.contains("lastError = nil"))
    }

    @Test
    func liveOverlayForwardsCurrentReactionToPetSprite() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("reaction: store.reaction(for: petInstance.id)"))
    }

    @Test
    func liveOverlayProvidesStablePerInstanceAnimationPhase() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("animationPhaseOffset: PetAnimationPhaseOffset.normalized("))
        #expect(source.contains("for: petInstance.id.uuidString"))
    }

    private func sourceFile(_ path: String) throws -> URL {
        try repositoryRoot().appending(path: path)
    }

    private func repositoryRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while currentURL.path != "/" {
            if FileManager.default.fileExists(atPath: currentURL.appending(path: "Package.swift").path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
