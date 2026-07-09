import Foundation
import Testing

@Suite
struct PetOverlayTransparencyTests {
    @Test
    func scrollableSessionBubbleDoesNotUseTintedBackgroundForHitTesting() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains(".background(Color.black.opacity("))
    }

    @Test
    func appKitHostingViewRoutesWheelEventsInsideTransparentScrollableGaps() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        #expect(source.contains("override func scrollWheel(with event: NSEvent)"))
        #expect(source.contains("descendantScrollView(at:"))
    }

    @Test
    func scrollableSessionBubbleOverlaysWheelOnlyEventCapture() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains(".overlay(SessionScrollWheelCapture())"))
        #expect(source.contains("NSApp.currentEvent?.type == .scrollWheel"))
        #expect(source.contains("private func scrollView(at windowPoint: NSPoint) -> NSScrollView?"))
    }

    @Test
    func collapsedChatBadgeUsesCompactVisualSize() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("static let collapsedChatBadgeSize: CGFloat = expandedChatControlSize"))
        #expect(source.contains(".frame(width: PetOverlayMetrics.collapsedChatBadgeSize, height: PetOverlayMetrics.collapsedChatBadgeSize)"))
        #expect(!source.contains(".frame(width: 46, height: 46)"))
    }

    @Test
    func collapsedChatBadgeUsesStatusTintInsteadOfAlwaysGreen() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
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
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("override var isOpaque: Bool"))
        #expect(source.contains("layer?.backgroundColor = NSColor.clear.cgColor"))
        #expect(source.contains("layer?.isOpaque = false"))
    }

    @Test
    func inlineReplyEditorUsesReplyLabelAndEscapeToCancel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
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
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("MenuBarExtra(\"Claude Pet\", systemImage: \"pawprint.circle\")"))
        #expect(source.contains(".menuBarExtraStyle(.menu)"))
        #expect(source.contains("PetMenuView("))
    }

    @Test
    func menuLinksToPetConfigurationAndFutureCreationSurface() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("@Environment(\\.openSettings)"))
        #expect(source.contains("openSettings()"))
        #expect(source.contains("bringConfigurationToFront()"))
        #expect(source.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(source.contains("first(where: Self.isConfigurationWindow)"))
        #expect(source.contains("window.styleMask.contains(.titled)"))
        #expect(source.contains("window.styleMask.contains(.closable)"))
        #expect(!source.contains("for window in NSApp.windows where !(window is PetPanel)"))
        #expect(source.contains("PetSettingsView("))
        #expect(source.contains("ClaudePetCatalog.builtInPetIDs"))
        #expect(!source.contains("PetConfigurationRow"))
    }

    @Test
    func menuKeepsOnlyTopLevelPetCommands() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Button(\"Respawn Pet\")"))
        #expect(source.contains("\"Hide Pet\" : \"Show Pet\""))
        #expect(source.contains("Label(\"Configure...\", systemImage: \"slider.horizontal.3\")"))
        #expect(source.contains("Button(\"Quit Claude Pet\")"))

        let menuStart = try #require(source.range(of: "private struct PetMenuView: View"))
        let menuEnd = try #require(source.range(of: "private struct PetSettingsView: View", range: menuStart.upperBound..<source.endIndex))
        let menuSource = String(source[menuStart.lowerBound..<menuEnd.lowerBound])

        #expect(!menuSource.contains("Toggle(\"Open at Login\""))
        #expect(!menuSource.contains("Section(\"Sprite\")"))
        #expect(!menuSource.contains("Section(\"Pixelation\")"))
        #expect(!menuSource.contains("Section(\"Context Lines\")"))
    }

    @Test
    func overlayPassesPixelationPreferenceToSprite() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("PetSprite("))
        #expect(source.contains("pixelation: petInstance.pixelation"))
        #expect(source.contains("pixelatedSpriteEffect"))
        #expect(source.contains(".id(petInstance.pixelation)"))
        #expect(source.contains("PixelatedSpriteRasterizer(pixelation: pixelation)"))
        #expect(source.contains("imageLayer.magnificationFilter = .nearest"))
        #expect(source.contains("bitmapImageRepForCachingDisplay"))
        #expect(!source.contains("PixelatedSpriteOverlay"))
    }

    @Test
    func menuAndOverlayExposeSessionContextLineCount() throws {
        let appSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let overlaySourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
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
    func petSettingsUseContainedCarouselAndTwoColumnControls() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("PetInstanceCarouselView("))
        #expect(source.contains("ScrollView(.horizontal, showsIndicators: false)"))
        #expect(source.contains("PetCarouselArrow(systemName: \"chevron.left\")"))
        #expect(source.contains("PetCarouselArrow(systemName: \"chevron.right\")"))
        #expect(source.contains("SpritePreviewGridBackground()"))
        #expect(source.contains("SettingsDesignPalette.root"))
        #expect(source.contains("Clouds - Classic"))
        #expect(source.contains("SpriteSummaryPanel("))
        #expect(source.contains("Button(\"Change Sprite...\")"))
        #expect(source.contains("Button(\"Delete Pet\", role: .destructive)"))
        #expect(source.contains("store.removeSelectedPet()"))
        #expect(source.contains("EmptyPetCollectionView"))
        #expect(!source.contains(".disabled(store.petInstances.count <= 1)"))
        #expect(source.contains("BehaviorSettingsPanel("))
        #expect(source.contains("PetDetailsSettingsPanel("))
        #expect(source.contains("HStack(alignment: .top, spacing: 14)"))
        #expect(source.contains("SettingSwitchRow(\"Hover bounce\""))
        #expect(source.contains(".toggleStyle(GradientSettingsToggleStyle())"))
        #expect(source.contains("LinearGradient(colors: [SettingsDesignPalette.switchPink, SettingsDesignPalette.switchTeal]"))
        #expect(source.contains(".frame(width: 18, height: 18)"))
        #expect(source.contains(".frame(width: 42, height: 24)"))
        #expect(source.contains(".frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)"))
        #expect(source.contains("TextField(\"\", text: nameBinding)"))
        #expect(!source.contains("private struct PetInstanceListView"))
        #expect(!source.contains("List(selection: selectedPetBinding)"))
    }

    @Test
    func petCarouselAffordancesOnlyShowWhenContentOverflows() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("let isOverflowing = carouselContentWidth > proxy.size.width"))
        #expect(source.contains("if isOverflowing {"))
        #expect(source.contains("ScrollView(.horizontal, showsIndicators: false)"))
        #expect(source.contains("PetCarouselArrow(systemName: \"chevron.left\")"))
        #expect(source.contains("PetCarouselArrow(systemName: \"chevron.right\")"))
        #expect(!source.contains("PetCarouselEndCapBar"))
        #expect(!source.contains("PetCarouselScrollbar"))
    }

    @Test
    func petSpriteUsesScalableCloudFamilyRenderer() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/PetOverlayView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("CloudFamilySprite("))
        #expect(source.contains("ScaledCloudFamilySprite("))
        #expect(source.contains("GeometryReader { proxy in"))
        #expect(source.contains("case .helperCloud"))
        #expect(source.contains("case .sleepCloud"))
        #expect(source.contains("case .focusCloud"))
        #expect(!source.contains("if petID == .classicClaude {\n                ClaudeSprite"))
        #expect(!source.contains("showsStatusDot"))
        #expect(!source.contains("statusDotColor"))
    }

    @Test
    func petStoreDoesNotSeedPetsOnFirstLaunchOrAfterDeletion() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/ClaudePet/ClaudePetStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("return ([], nil)"))
        #expect(source.contains("return (decoded.map(normalizedCloudFamilyInstance), nil)"))
        #expect(!source.contains("cloudFamilyCollection(from:"))
        #expect(!source.contains("starterCloudFamilyInstances"))
        #expect(source.contains("@Published private(set) var selectedPetInstanceID: PetInstance.ID?"))
    }
}
