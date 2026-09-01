import AppKit
import PetsCore
import SwiftUI
import Testing
@testable import Pets

@Suite(.serialized)
@MainActor
struct PetKeyConversionInteractionTests {
    @Test(arguments: [PetRarity.common, .rare])
    func singleAvailableConversionMountsWithoutASlider(sourceRarity: PetRarity) throws {
        let suiteName = "PetKeyConversionInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = PetCollectionState(
            keyInventory: PetKeyInventory(
                rarity: sourceRarity,
                count: PetRarity.keyUpgradeCost
            )
        )
        defaults.set(try JSONEncoder().encode(state), forKey: "petCollectionState")
        let targetRarity = try #require(sourceRarity.nextRarity)

        let store = PetStore(
            harness: EmptyInteractionHarness(),
            defaults: defaults,
            usageSources: [],
            releaseGift: nil
        )
        let hostingView = NSHostingView(
            rootView: PetKeyConversionPopover(
                store: store,
                sourceRarity: sourceRarity,
                targetRarity: targetRarity,
                maxConversionCount: 1,
                isPresented: .constant(true)
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 330, height: 240)
        hostingView.layoutSubtreeIfNeeded()

        #expect(descendants(of: NSSlider.self, in: hostingView).isEmpty)
    }

    private func descendants<T: NSView>(of type: T.Type, in root: NSView) -> [T] {
        root.subviews.flatMap { subview -> [T] in
            let match = (subview as? T).map { [$0] } ?? []
            return match + descendants(of: type, in: subview)
        }
    }
}

private struct EmptyInteractionHarness: PetHarness {
    let id = "key-conversion-interaction-test"
    let displayName = "Key conversion interaction test"

    func scan() throws -> [HarnessSession] { [] }

    func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        .focusedExactTarget(appName: displayName)
    }

    func sendReply(_ message: String, to session: HarnessSession) throws {}
}
