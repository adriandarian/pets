import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetInstanceTests {
    @Test
    func defaultInstanceUsesExistingCatalogDefaults() {
        let instance = PetInstance.defaultInstance()
        let definition = PetCatalog.definition(for: PetCatalog.defaultPetID)

        #expect(instance.name == "Cumulus")
        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == definition?.defaults.pixelation)
        #expect(instance.sessionContextLineCount == definition?.defaults.sessionContextLineCount)
        #expect(instance.animationSettings == definition?.defaults.animationSettings)
        #expect(instance.isVisible)
        #expect(instance.trackingProviders == [.claudeCode])
    }

    @Test
    func updatingSpriteClampsPixelationToNewSpriteCapability() {
        var instance = PetInstance.defaultInstance()
        instance.pixelation = .chunky

        instance.updatePetID(.cirrusCloud)

        #expect(instance.petID == .cirrusCloud)
        #expect(instance.pixelation == .medium)
    }

    @Test
    func userInitiatedChangeRenamesLegacyCuteCloudDefault() {
        var instance = PetInstance(
            name: "Cute Cloud",
            petID: .cuteCloud,
            pixelation: .off,
            sessionContextLineCount: 2
        )

        instance.changePetID(.nimbusCloud)

        #expect(instance.petID == .nimbusCloud)
        #expect(instance.name == "Nimbus")
    }

    @Test
    func userInitiatedChangePreservesCustomName() {
        var instance = PetInstance(
            name: "Stormy",
            petID: .cuteCloud,
            pixelation: .off,
            sessionContextLineCount: 2
        )

        instance.changePetID(.snowCloud)

        #expect(instance.petID == .snowCloud)
        #expect(instance.name == "Stormy")
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
                ),
                trackingProviders: [.codex, .githubCopilot]
            )
        ]

        let data = try JSONEncoder().encode(instances)
        let decoded = try JSONDecoder().decode([PetInstance].self, from: data)

        #expect(decoded == instances)
    }

    @Test
    func legacyPetInstanceWithoutNewerSettingsUsesSafeDefaults() throws {
        let id = "00000000-0000-0000-0000-000000000001"
        let data = Data(#"""
        {
          "id": "\#(id)",
          "name": "My Cloud",
          "petID": "cute-cloud",
          "pixelation": "medium",
          "sessionContextLineCount": 3
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(PetInstance.self, from: data)

        #expect(decoded.id.uuidString == id)
        #expect(decoded.animationSettings == .default)
        #expect(decoded.isVisible)
        #expect(decoded.overlayPosition == .default)
        #expect(decoded.trackingProviders == [.claudeCode])
    }

    @Test
    func legacyAnimationAndOverlaySettingsDecodeMissingFields() throws {
        let data = Data(#"""
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "My Cloud",
          "petID": "cute-cloud",
          "pixelation": "off",
          "sessionContextLineCount": 2,
          "animationSettings": {
            "isHoverBounceEnabled": false
          },
          "isVisible": false,
          "overlayPosition": {}
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(PetInstance.self, from: data)

        #expect(decoded.animationSettings.isHoverBounceEnabled == false)
        #expect(decoded.animationSettings.isIdleMotionEnabled)
        #expect(decoded.animationSettings.areStatusMoodsEnabled)
        #expect(decoded.overlayPosition == .default)
    }

    @Test
    func removedPetSelectionMigratesToCuteCloud() {
        let migrated = PetInstance.migratedDefault(
            petID: PetID(rawValue: "helper-cloud"),
            pixelation: .chunky,
            sessionContextLineCount: 3
        )

        #expect(migrated.name == "Cumulus")
        #expect(migrated.petID == .cuteCloud)
        #expect(migrated.pixelation == .medium)
        #expect(migrated.sessionContextLineCount == 3)
    }

    @Test
    func decodedCloudFamilySelectionRemainsSelected() throws {
        let instance = PetInstance(
            name: "Stormy",
            petID: .nimbusCloud,
            pixelation: .off,
            sessionContextLineCount: 2
        )

        let decoded = try JSONDecoder().decode(
            PetInstance.self,
            from: JSONEncoder().encode(instance)
        ).normalizedForCurrentCatalog()

        #expect(decoded.petID == .nimbusCloud)
        #expect(decoded.name == "Stormy")
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
