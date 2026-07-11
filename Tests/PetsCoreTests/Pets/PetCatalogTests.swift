import Testing
@testable import PetsCore

@Suite
struct PetCatalogTests {
    @Test
    func registryContainsEveryExistingPetExactlyOnceInExistingOrder() {
        #expect(PetCatalog.definitions.map(\.id) == [
            .cuteCloud,
            .classicCloud,
            .helperCloud,
            .sleepCloud,
            .focusCloud,
            .codeBot,
            .terminalCube,
            .bookstackBuddy,
            .sproutBuddy,
            .pebblePal,
            .pocketStar,
            .teaCup,
            .nightLamp,
            .tinyRocket,
            .voxelCat,
            .voxelSlime,
            .voxelDragon
        ])
        #expect(Set(PetCatalog.definitions.map(\.id)).count == 17)
    }

    @Test
    func catalogCompatibilityAPIsDelegateToDefinitions() throws {
        let cuteCloud = try #require(PetCatalog.definition(for: .cuteCloud))

        #expect(cuteCloud is CuteCloudPetDefinition)
        #expect(PetCatalog.displayName(for: .cuteCloud) == cuteCloud.displayName)
        #expect(PetCatalog.maximumPixelation(for: .cuteCloud) == cuteCloud.capabilities.maximumPixelation)
        #expect(PetCatalog.renderFamily(for: .cuteCloud) == .cuteCloud)
    }

    @Test
    func builtInCategoriesIncludeVoxelPetsInOrder() throws {
        let category = try #require(PetCatalog.builtInCategories.first { $0.id == "voxel-pets" })

        #expect(category.displayName == "Voxel Pets")
        #expect(category.petIDs == [.voxelCat, .voxelSlime, .voxelDragon])
    }

    @Test
    func voxelPetsExposeDisplayNamesAndChunkyPixelation() {
        #expect(PetCatalog.displayName(for: .voxelCat) == "Voxel Cat")
        #expect(PetCatalog.displayName(for: .voxelSlime) == "Voxel Slime")
        #expect(PetCatalog.displayName(for: .voxelDragon) == "Voxel Dragon")

        #expect(PetCatalog.maximumPixelation(for: .voxelCat) == .chunky)
        #expect(PetCatalog.maximumPixelation(for: .voxelSlime) == .chunky)
        #expect(PetCatalog.maximumPixelation(for: .voxelDragon) == .chunky)
    }

    @Test
    func voxelPetInstancesPreserveChunkyPixelation() {
        let instance = PetInstance(
            name: "Voxel Cat",
            petID: .voxelCat,
            pixelation: .chunky,
            sessionContextLineCount: 2
        )

        #expect(instance.petID == .voxelCat)
        #expect(instance.pixelation == .chunky)
    }
}
