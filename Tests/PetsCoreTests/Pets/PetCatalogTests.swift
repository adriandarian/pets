import Testing
@testable import PetsCore

@Suite
struct PetCatalogTests {
    @Test
    func cuteCloudIsTheOnlyRegisteredPet() throws {
        #expect(PetCatalog.definitions.map(\.id) == [.cuteCloud])
        #expect(PetCatalog.builtInPetIDs == [.cuteCloud])

        let category = try #require(PetCatalog.builtInCategories.first)
        #expect(PetCatalog.builtInCategories.count == 1)
        #expect(category.id == "cloud-pets")
        #expect(category.displayName == "Cloud Pets")
        #expect(category.petIDs == [.cuteCloud])
    }

    @Test
    func cuteCloudDefinitionOwnsEveryAnimationState() throws {
        let cuteCloud = try #require(PetCatalog.definition(for: .cuteCloud))

        #expect(cuteCloud is CuteCloudPetDefinition)
        #expect(cuteCloud.displayName == "Cute Cloud")
        #expect(cuteCloud.capabilities.maximumPixelation == .medium)
        guard case let .assetPack(pack) = cuteCloud.renderSource else {
            Issue.record("Cute Cloud must use an asset pack")
            return
        }
        for state in PetVisualState.allCases {
            #expect(pack.animation(for: state) != nil)
        }
    }

    @Test
    func removedPetIDsResolveToCuteCloud() {
        #expect(PetCatalog.resolvedPetID(PetID(rawValue: "helper-cloud")) == .cuteCloud)
        #expect(PetCatalog.resolvedPetID(PetID(rawValue: "voxel-dragon")) == .cuteCloud)
        #expect(PetCatalog.resolvedPetID(PetID(rawValue: "custom:old-pet")) == .cuteCloud)
        #expect(PetCatalog.resolvedPetID(.cuteCloud) == .cuteCloud)
    }

    @Test
    func pixelationAlwaysUsesCuteCloudCapability() {
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .cuteCloud) == .medium)
        #expect(PetCatalog.pixelation(.chunky, allowedFor: PetID(rawValue: "helper-cloud")) == .medium)
    }
}
