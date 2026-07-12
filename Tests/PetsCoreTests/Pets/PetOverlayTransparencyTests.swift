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

        #expect(source.contains("MenuBarExtra(\"Pets\", systemImage: \"pawprint.circle\")"))
        #expect(source.contains(".menuBarExtraStyle(.menu)"))
        #expect(source.contains("PetMenuView("))
    }

    @Test
    func menuLinksToPetConfigurationAndFutureCreationSurface() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let settingsSourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let settingsSource = try String(contentsOf: settingsSourceURL, encoding: .utf8)

        #expect(source.contains("@Environment(\\.openSettings)"))
        #expect(source.contains("openSettings()"))
        #expect(source.contains("bringConfigurationToFront()"))
        #expect(source.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(source.contains("first(where: Self.isConfigurationWindow)"))
        #expect(source.contains("window.styleMask.contains(.titled)"))
        #expect(source.contains("window.styleMask.contains(.closable)"))
        #expect(!source.contains("for window in NSApp.windows where !(window is PetPanel)"))
        #expect(source.contains("PetSettingsView("))
        #expect(settingsSource.contains("Text(PetCatalog.displayName(for: pet.petID))"))
        #expect(settingsSource.contains("PetCatalog.builtInCategories"))
        #expect(!source.contains("PetConfigurationRow"))
    }

    @Test
    func menuKeepsOnlyTopLevelPetCommands() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetsApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Button(\"Respawn Pet\")"))
        #expect(source.contains("\"Hide Pet\" : \"Show Pet\""))
        #expect(source.contains("Label(\"Configure...\", systemImage: \"slider.horizontal.3\")"))
        #expect(source.contains("Button(\"Quit Pets\")"))

        let menuStart = try #require(source.range(of: "private struct PetMenuView: View"))
        let menuEnd = try #require(source.range(of: "private enum LoginItemController", range: menuStart.upperBound..<source.endIndex))
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
        #expect(source.contains("status: store.dominantStatus"))
        #expect(source.contains("hasActiveSessions: !store.visibleSessions.isEmpty"))
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
        let appSourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
        let overlaySourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let appSource = try String(contentsOf: appSourceURL, encoding: .utf8)
        let overlaySource = try String(contentsOf: overlaySourceURL, encoding: .utf8)

        #expect(appSource.contains("Text(\"Context\")"))
        #expect(appSource.contains("PetSessionContextLineCount.supportedRange"))
        #expect(appSource.contains("Slider("))
        #expect(appSource.contains("step: 1"))
        #expect(appSource.contains("contextLineCountSliderBinding"))
        #expect(appSource.contains("store.updateSelectedPetContextLineCount"))
        #expect(!appSource.contains("Picker(\"Context Lines\""))
        #expect(overlaySource.contains("contextLineCount: petInstance.sessionContextLineCount"))
        #expect(overlaySource.contains(".lineLimit(contextLineCount)"))
        #expect(!overlaySource.contains(".lineLimit(2)"))
    }

    @Test
    func petSettingsUseNativeAdaptiveSidebarAndDetailLayout() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("NavigationSplitView"))
        #expect(source.contains("private struct PetSidebar: View"))
        #expect(source.contains("List(selection: selectedPetBinding)"))
        #expect(source.contains(".listStyle(.sidebar)"))
        #expect(source.contains("private struct PetDetailPane: View"))
        #expect(source.contains("SpritePreviewGridBackground()"))
        #expect(source.contains("Color(nsColor: .separatorColor)"))
        #expect(source.contains("PetCatalog.category(for: pet.petID)?.displayName"))
        #expect(source.contains("Text(PetCatalog.displayName(for: pet.petID))"))
        #expect(source.contains("Menu {"))
        #expect(source.contains("Button(\"Duplicate\")"))
        #expect(source.contains("Button(\"Delete\", role: .destructive)"))
        #expect(source.contains("Button(\"Change Sprite...\")"))
        #expect(source.contains("SpritePickerSheet"))
        #expect(source.contains("Button(\"Delete Pet\", role: .destructive)"))
        #expect(source.contains("store.removeSelectedPet()"))
        #expect(source.contains("EmptyPetCollectionView"))
        #expect(!source.contains(".disabled(store.petInstances.count <= 1)"))
        #expect(source.contains("SettingSwitchRow(\"Hover bounce\""))
        #expect(source.contains(".toggleStyle(.switch)"))
        #expect(source.contains("TextField(\"\", text: nameBinding)"))
        #expect(!source.contains(".preferredColorScheme("))
        #expect(!source.contains("SettingsDesignPalette"))
        #expect(!source.contains("GradientSettingsToggleStyle"))
        #expect(!source.contains("PetInstanceCarouselView"))
        #expect(!source.contains("ScrollView(.horizontal"))
    }

    @Test
    func petSidebarSelectionUsesStoreAsSourceOfTruth() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("get: { store.selectedPetInstanceID }"))
        #expect(source.contains("store.selectPetInstance(selectedID)"))
        #expect(source.contains("ForEach(store.petInstances)"))
        #expect(source.contains("PetSidebarRow(pet: pet)"))
        #expect(source.contains("store.addPet()"))
        #expect(!source.contains("carouselContentWidth"))
        #expect(!source.contains("PetCarouselArrow"))
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
    func settingsOfferCloudFamilySpriteSelection() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("SpritePickerSheet"))
        #expect(source.contains("SpritePickerCard"))
        #expect(source.contains("Change Sprite..."))
        #expect(source.contains("ForEach(PetCatalog.builtInCategories"))
    }

    @Test
    func overlayOffersCloudFamilySwitching() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("ForEach(PetCatalog.builtInPetIDs"))
        #expect(source.contains("store.selectPet("))
        #expect(source.contains(".contextMenu"))
    }

    @Test
    func petStoreDoesNotSeedPetsOnFirstLaunchOrAfterDeletion() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let persistenceSourceURL = try sourceFile("Sources/Pets/PetSettingsPersistence.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let persistenceSource = try String(contentsOf: persistenceSourceURL, encoding: .utf8)

        #expect(persistenceSource.contains("return ([], nil)"))
        #expect(persistenceSource.contains("return (decoded.map { $0.normalizedForCurrentCatalog() }, nil)"))
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
        #expect(source.contains("harness: any PetHarness = ClaudeHarness()"))
        #expect(!source.contains("ClaudeSessionScanner"))
        #expect(!source.contains("ClaudeReplySender"))
        #expect(!source.contains("SessionActivating"))
        #expect(!source.contains("[ClaudeSession]"))
    }

    @Test
    func petStoreCoordinatesCompletionAndErrorReactions() throws {
        let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("@Published private(set) var currentReaction: PetReaction?"))
        #expect(source.contains("private var sessionObservationCoordinator = PetSessionObservationCoordinator()"))
        #expect(source.contains("private static let completionReactionDuration: Duration = .seconds(4)"))
        let sessionObservation = try #require(source.range(
            of: ".observeSuccessfulSessions(scannedSessions)"
        ))
        let errorClear = try #require(source.range(
            of: "setLastError(error)",
            range: sessionObservation.upperBound..<source.endIndex
        ))
        #expect(sessionObservation.lowerBound < errorClear.lowerBound)
        #expect(source.contains("private func beginCompletionReaction()"))
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

        #expect(source.contains("reaction: store.currentReaction"))
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
