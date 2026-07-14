import Testing
@testable import PetsCore

@Suite
struct PetCatalogTests {
    @Test
    func cloudFamilyIsTheOnlyRegisteredFamily() throws {
        let cloudPetIDs: [PetID] = [
            .cuteCloud,
            .nimbusCloud,
            .cirrusCloud,
            .lenticularCloud,
            .snowCloud,
        ]

        #expect(PetCatalog.definitions.map(\.id) == cloudPetIDs)
        #expect(PetCatalog.builtInPetIDs == cloudPetIDs)

        let category = try #require(PetCatalog.builtInCategories.first)
        #expect(PetCatalog.builtInCategories.count == 1)
        #expect(category.id == "cloud-pets")
        #expect(category.displayName == "Cloud Pets")
        #expect(category.petIDs == cloudPetIDs)
    }

    @Test
    func everyCloudSpeciesHasItsOwnConcreteDefinition() throws {
        #expect(PetCatalog.definition(for: .cuteCloud) is CumulusCloudPetDefinition)
        #expect(PetCatalog.definition(for: .nimbusCloud) is NimbusCloudPetDefinition)
        #expect(PetCatalog.definition(for: .cirrusCloud) is CirrusCloudPetDefinition)
        #expect(PetCatalog.definition(for: .lenticularCloud) is LenticularCloudPetDefinition)
        #expect(PetCatalog.definition(for: .snowCloud) is SnowCloudPetDefinition)

        #expect(PetCatalog.displayName(for: .cuteCloud) == "Cumulus")
        #expect(PetCatalog.displayName(for: .nimbusCloud) == "Nimbus")
        #expect(PetCatalog.displayName(for: .cirrusCloud) == "Cirrus")
        #expect(PetCatalog.displayName(for: .lenticularCloud) == "Lenticular")
        #expect(PetCatalog.displayName(for: .snowCloud) == "Snow Cloud")
    }

    @Test
    func cloudRaritiesDriveChestEligibility() {
        #expect(PetCatalog.rarity(for: .cuteCloud) == .common)
        #expect(PetCatalog.rarity(for: .nimbusCloud) == .common)
        #expect(PetCatalog.rarity(for: .cirrusCloud) == .rare)
        #expect(PetCatalog.rarity(for: .lenticularCloud) == .rare)
        #expect(PetCatalog.rarity(for: .snowCloud) == .legendary)

        #expect(PetCatalog.petIDs(for: .common) == [.cuteCloud, .nimbusCloud])
        #expect(PetCatalog.petIDs(for: .rare) == [.cirrusCloud, .lenticularCloud])
        #expect(PetCatalog.petIDs(for: .legendary) == [.snowCloud])
    }

    @Test
    func cumulusOwnsEverySteadyAnimationState() throws {
        let cumulus = try #require(PetCatalog.definition(for: .cuteCloud))

        #expect(cumulus.capabilities.maximumPixelation == .medium)
        guard case let .assetPack(pack) = cumulus.renderSource else {
            Issue.record("Cumulus must use an asset pack")
            return
        }
        for state in [
            PetVisualState.idle,
            .busy,
            .waiting,
            .excited,
            .sleeping,
        ] {
            #expect(pack.animation(for: state) != nil)
        }
    }

    @Test
    func newCloudSpeciesUseIdleFallbackForOptionalStates() throws {
        for petID in [PetID.nimbusCloud, .cirrusCloud, .lenticularCloud, .snowCloud] {
            let definition = try #require(PetCatalog.definition(for: petID))
            guard case let .assetPack(pack) = definition.renderSource else {
                Issue.record("Every cloud species must use an asset pack")
                continue
            }

            #expect(pack.animation(for: .idle) != nil)
            #expect(pack.animation(for: .busy) == nil)
            #expect(pack.animation(for: .waiting) == nil)
            #expect(pack.animation(for: .excited) == nil)
            #expect(pack.animation(for: .sleeping) == nil)
            #expect(pack.resolvedAnimation(for: .busy) == pack.idle)
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
    func pixelationUsesCloudFamilyCapabilities() {
        for petID in PetCatalog.builtInPetIDs {
            #expect(PetCatalog.pixelation(.chunky, allowedFor: petID) == .medium)
        }
        #expect(PetCatalog.pixelation(.chunky, allowedFor: PetID(rawValue: "helper-cloud")) == .medium)
    }
}
