import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetInstanceTests {
    @Test
    func defaultInstanceUsesExistingCatalogDefaults() {
        let instance = PetInstance.defaultInstance()

        #expect(instance.name == "Cute Cloud")
        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == .off)
        #expect(instance.sessionContextLineCount == 2)
        #expect(instance.animationSettings.isHoverBounceEnabled)
        #expect(instance.animationSettings.isIdleMotionEnabled)
        #expect(instance.animationSettings.areStatusMoodsEnabled)
        #expect(instance.isVisible)
    }

    @Test
    func updatingSpriteClampsPixelationToNewSpriteCapability() {
        var instance = PetInstance.defaultInstance()
        instance.pixelation = .chunky

        instance.updatePetID(.cuteCloud)

        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == .medium)
    }

    @Test
    func contextLineCountIsClampedOnAssignment() {
        var instance = PetInstance.defaultInstance()

        instance.updateSessionContextLineCount(99)

        #expect(instance.sessionContextLineCount == 4)
    }

    @Test
    func petInstancesRoundTripThroughJSON() throws {
        let instances = [
            PetInstance(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Classic",
                petID: .classicCloud,
                pixelation: .chunky,
                sessionContextLineCount: 4,
                animationSettings: PetAnimationSettings(
                    isHoverBounceEnabled: false,
                    isIdleMotionEnabled: true,
                    areStatusMoodsEnabled: false
                ),
                isVisible: false,
                overlayPosition: PetOverlayPosition(
                    origin: CGPoint(x: 10, y: 20),
                    horizontalPlacement: .leading
                )
            )
        ]

        let data = try JSONEncoder().encode(instances)
        let decoded = try JSONDecoder().decode([PetInstance].self, from: data)

        #expect(decoded == instances)
    }

    @Test
    func migratedDefaultUsesExistingPreferenceValues() {
        let migrated = PetInstance.migratedDefault(
            petID: .classicCloud,
            pixelation: .chunky,
            sessionContextLineCount: 3
        )

        #expect(migrated.name == "Classic Cloud")
        #expect(migrated.petID == .classicCloud)
        #expect(migrated.pixelation == .chunky)
        #expect(migrated.sessionContextLineCount == 3)
    }

    @Test
    func legacyClassicClaudeIDDecodesAsClassicCloud() throws {
        let id = PetID(rawValue: "classic-claude")

        #expect(id == .classicCloud)
        #expect(id.rawValue == "classic-cloud")
    }
}
