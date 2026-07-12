import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetInstanceTests {
    @Test
    func defaultInstanceUsesExistingCatalogDefaults() {
        let instance = PetInstance.defaultInstance()
        let definition = PetCatalog.definition(for: PetCatalog.defaultPetID)

        #expect(instance.name == "Cute Cloud")
        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == definition?.defaults.pixelation)
        #expect(instance.sessionContextLineCount == definition?.defaults.sessionContextLineCount)
        #expect(instance.animationSettings == definition?.defaults.animationSettings)
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
                name: "My Cloud",
                petID: .cuteCloud,
                pixelation: .medium,
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
    func removedPetSelectionMigratesToCuteCloud() {
        let migrated = PetInstance.migratedDefault(
            petID: PetID(rawValue: "helper-cloud"),
            pixelation: .chunky,
            sessionContextLineCount: 3
        )

        #expect(migrated.name == "Cute Cloud")
        #expect(migrated.petID == .cuteCloud)
        #expect(migrated.pixelation == .medium)
        #expect(migrated.sessionContextLineCount == 3)
    }

    @Test
    func decodedLegacyInstanceNormalizesToCuteCloud() throws {
        let currentData = try JSONEncoder().encode(PetInstance.defaultInstance())
        let currentJSON = try #require(String(data: currentData, encoding: .utf8))
        let legacyData = try #require(
            currentJSON.replacingOccurrences(of: "cute-cloud", with: "voxel-cat").data(using: .utf8)
        )
        let decoded = try JSONDecoder().decode(PetInstance.self, from: legacyData)
        let normalized = decoded.normalizedForCurrentCatalog()

        #expect(normalized.petID == .cuteCloud)
        #expect(normalized.pixelation == .off)
    }
}
