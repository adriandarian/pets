import AppKit
import PetsCore
import SwiftUI
import Testing
@testable import Pets

@Suite(.serialized)
@MainActor
struct PetDragInteractionTests {
    @Test
    func resizeSurfaceOwnsOnlyLeftMouseDownEventsInsideItsBounds() {
        let view = PetScreenCoordinateDragView(frame: NSRect(x: 0, y: 0, width: 20, height: 40))

        view.eventTypeProvider = { .mouseMoved }
        #expect(view.hitTest(NSPoint(x: 10, y: 20)) == nil)

        view.eventTypeProvider = { .rightMouseDown }
        #expect(view.hitTest(NSPoint(x: 10, y: 20)) == nil)

        view.eventTypeProvider = { .leftMouseDown }
        #expect(view.hitTest(NSPoint(x: 10, y: 20)) === view)
        #expect(view.hitTest(NSPoint(x: 30, y: 20)) == nil)
        #expect(view.mouseDownCanMoveWindow == false)
    }

    @Test
    func resizeSurfaceReportsStableScreenCoordinateTranslationAndEndsOnce() {
        let view = PetScreenCoordinateDragView(frame: NSRect(x: 0, y: 0, width: 20, height: 40))
        var translations: [CGSize] = []
        var endCount = 0
        view.onChanged = { translations.append($0) }
        view.onEnded = { endCount += 1 }

        view.beginDrag(at: NSPoint(x: 500, y: 400))
        view.continueDrag(to: NSPoint(x: 440, y: 475))
        view.continueDrag(to: NSPoint(x: 420, y: 450))
        view.endDrag()
        view.continueDrag(to: NSPoint(x: 300, y: 300))

        #expect(translations == [
            CGSize(width: -60, height: 75),
            CGSize(width: -80, height: 50)
        ])
        #expect(endCount == 1)
    }

    @Test
    func petMoveSurfaceOwnsOnlyLeftMouseDownWithoutResizeCallbacks() {
        let view = PetWindowDragView(frame: NSRect(x: 0, y: 0, width: 96, height: 96))

        view.eventTypeProvider = { .mouseMoved }
        #expect(view.hitTest(NSPoint(x: 48, y: 48)) == nil)

        view.eventTypeProvider = { .rightMouseDown }
        #expect(view.hitTest(NSPoint(x: 48, y: 48)) == nil)

        view.eventTypeProvider = { .leftMouseDown }
        #expect(view.hitTest(NSPoint(x: 48, y: 48)) === view)
    }

    @Test
    func mountedOverlayKeepsResizeHitTargetsSmallAndSeparateFromPetMovement() async throws {
        let suiteName = "PetDragInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var pet = PetInstance.defaultInstance()
        pet.trackingProviders = [.codex]
        defaults.set(try JSONEncoder().encode([pet]), forKey: "petInstances")
        defaults.set(pet.id.uuidString, forKey: "selectedPetInstanceID")

        let sessions = (0..<6).map { index in
            HarnessSession(
                harnessID: PetTrackingProvider.codex.rawValue,
                harnessDisplayName: PetTrackingProvider.codex.displayName,
                sessionID: "interaction-session-\(index)",
                processID: nil,
                cwd: "/tmp",
                title: "Interaction session \(index)",
                chatPreview: "Resize this session stack",
                kind: "task",
                entrypoint: "Codex app",
                status: .busy,
                updatedAt: Date().addingTimeInterval(TimeInterval(-index)),
                startedAt: Date().addingTimeInterval(TimeInterval(-index))
            )
        }
        let store = PetStore(
            harness: InteractionTestHarness(sessions: sessions),
            defaults: defaults,
            usageSources: [],
            releaseGift: nil
        )
        store.start()

        for _ in 0..<100 where store.visibleSessions(for: pet.id).isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.visibleSessions(for: pet.id).count == sessions.count)

        let panel = PetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hostingView = FirstMouseHostingView(
            rootView: PetOverlayView(
                store: store,
                updateController: PetUpdateController(installedVersion: "test"),
                petInstanceID: pet.id,
                openConfiguration: {}
            )
        )
        panel.contentView = hostingView
        hostingView.frame = NSRect(x: 0, y: 0, width: 620, height: 560)
        panel.layoutIfNeeded()

        for _ in 0..<10 {
            await Task.yield()
            hostingView.layoutSubtreeIfNeeded()
        }

        let resizeViews = descendants(of: PetScreenCoordinateDragView.self, in: hostingView)
        let petMoveViews = descendants(of: PetWindowDragView.self, in: hostingView)
        #expect(resizeViews.count == 2)
        #expect(petMoveViews.count == 1)
        #expect(panel.isMovableByWindowBackground == false)

        let resizeFrames = resizeViews.map { hostingView.convert($0.bounds, from: $0) }
        let petMoveFrame = try #require(petMoveViews.first.map { hostingView.convert($0.bounds, from: $0) })
        #expect(resizeFrames.contains { approximately($0.size, equals: CGSize(width: 15, height: 34)) })
        #expect(resizeFrames.contains { approximately($0.size, equals: CGSize(width: 34, height: 15)) })
        #expect(resizeFrames.allSatisfy { !$0.intersects(petMoveFrame) })

        let panelFrameBeforeResize = panel.frame
        let horizontalResizeView = try #require(resizeViews.first {
            approximately($0.bounds.size, equals: CGSize(width: 15, height: 34))
        })
        let horizontalFrameBeforeResize = hostingView.convert(
            horizontalResizeView.bounds,
            from: horizontalResizeView
        )
        horizontalResizeView.beginDrag(at: NSPoint(x: 500, y: 400))
        horizontalResizeView.continueDrag(to: NSPoint(x: 440, y: 400))
        horizontalResizeView.endDrag()
        await settleLayout(hostingView)

        let horizontalResizeViewAfter = try #require(
            descendants(of: PetScreenCoordinateDragView.self, in: hostingView).first {
                approximately($0.bounds.size, equals: CGSize(width: 15, height: 34))
            }
        )
        let horizontalFrameAfterResize = hostingView.convert(
            horizontalResizeViewAfter.bounds,
            from: horizontalResizeViewAfter
        )
        let petMoveFrameAfterWidthResize = try #require(
            descendants(of: PetWindowDragView.self, in: hostingView).first.map {
                hostingView.convert($0.bounds, from: $0)
            }
        )
        #expect(horizontalFrameAfterResize.minX < horizontalFrameBeforeResize.minX - 40)
        #expect(approximately(petMoveFrameAfterWidthResize, equals: petMoveFrame))
        #expect(panel.frame == panelFrameBeforeResize)

        let sessionScrollView = try #require(
            descendants(of: NSScrollView.self, in: hostingView).max {
                $0.bounds.height < $1.bounds.height
            }
        )
        let scrollHeightBeforeResize = hostingView.convert(
            sessionScrollView.bounds,
            from: sessionScrollView
        ).height
        let verticalResizeView = try #require(
            descendants(of: PetScreenCoordinateDragView.self, in: hostingView).first {
                approximately($0.bounds.size, equals: CGSize(width: 34, height: 15))
            }
        )
        verticalResizeView.beginDrag(at: NSPoint(x: 500, y: 400))
        verticalResizeView.continueDrag(to: NSPoint(x: 500, y: 480))
        verticalResizeView.endDrag()
        await settleLayout(hostingView)

        let sessionScrollViewAfter = try #require(
            descendants(of: NSScrollView.self, in: hostingView).max {
                $0.bounds.height < $1.bounds.height
            }
        )
        let scrollHeightAfterResize = hostingView.convert(
            sessionScrollViewAfter.bounds,
            from: sessionScrollViewAfter
        ).height
        let petMoveFrameAfterHeightResize = try #require(
            descendants(of: PetWindowDragView.self, in: hostingView).first.map {
                hostingView.convert($0.bounds, from: $0)
            }
        )
        #expect(scrollHeightAfterResize > scrollHeightBeforeResize + 20)
        #expect(approximately(petMoveFrameAfterHeightResize, equals: petMoveFrame))
        #expect(panel.frame == panelFrameBeforeResize)

        panel.close()
    }

    private func settleLayout(_ view: NSView) async {
        for _ in 0..<10 {
            await Task.yield()
            view.layoutSubtreeIfNeeded()
        }
    }

    private func descendants<T: NSView>(of type: T.Type, in root: NSView) -> [T] {
        root.subviews.flatMap { subview -> [T] in
            let match = (subview as? T).map { [$0] } ?? []
            return match + descendants(of: type, in: subview)
        }
    }

    private func approximately(_ lhs: CGSize, equals rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }

    private func approximately(_ lhs: CGRect, equals rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 0.5
            && abs(lhs.minY - rhs.minY) < 0.5
            && approximately(lhs.size, equals: rhs.size)
    }
}

private struct InteractionTestHarness: PetHarness {
    let id = "interaction-test"
    let displayName = "Interaction test"
    let sessions: [HarnessSession]

    func scan() throws -> [HarnessSession] { sessions }

    func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        .focusedExactTarget(appName: displayName)
    }

    func sendReply(_ message: String, to session: HarnessSession) throws {}
}
