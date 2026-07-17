import Testing
@testable import PetsCore

@Suite
struct PetCatalogTests {
    @Test
    func tesslingIdentifiersAndCategoryMetadataAreStable() {
        #expect(PetID.knotling.rawValue == "knotling")
        #expect(PetID.prismite.rawValue == "prismite")
        #expect(PetID.orbitling.rawValue == "orbitling")
        #expect(PetCategoryDescriptor.tesslings.id == "tesslings")
        #expect(PetCategoryDescriptor.tesslings.displayName == "Tesslings")
        #expect(PetCategoryDescriptor.tesslings.order == 1)
    }

    @Test
    func knotlingDefinitionOwnsItsCatalogAndAnimationContract() throws {
        let definition = try #require(PetCatalog.definition(for: .knotling))
        #expect(definition is KnotlingPetDefinition)
        #expect(definition.displayName == "Knotling")
        #expect(definition.rarity == .common)
        #expect(definition.capabilities.maximumPixelation == .chunky)
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Knotling must use an asset pack")
            return
        }
        #expect(pack.idle.frames.count == 8)
        #expect(pack.busy?.frames.count == 4)
        #expect(pack.waiting?.frames.count == 4)
        #expect(pack.excited?.frames.count == 5)
        #expect(pack.sleeping?.frames.count == 4)
    }

    @Test
    func prismiteDefinitionOwnsItsCatalogAndAnimationContract() throws {
        let definition = try #require(PetCatalog.definition(for: .prismite))
        #expect(definition is PrismitePetDefinition)
        #expect(definition.displayName == "Prismite")
        #expect(definition.rarity == .rare)
        #expect(definition.capabilities.maximumPixelation == .chunky)
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Prismite must use an asset pack")
            return
        }
        #expect(pack.idle.frames.count == 8)
        #expect(pack.busy?.frames.count == 4)
        #expect(pack.waiting?.frames.count == 4)
        #expect(pack.excited?.frames.count == 5)
        #expect(pack.sleeping?.frames.count == 4)
    }

    @Test
    func registeredFamiliesIncludeCloudsAndReleasedTesslings() throws {
        let cloudPetIDs: [PetID] = [
            .cuteCloud,
            .nimbusCloud,
            .cirrusCloud,
            .lenticularCloud,
            .snowCloud,
        ]
        let tesslingPetIDs: [PetID] = [.knotling, .prismite]
        let allPetIDs = cloudPetIDs + tesslingPetIDs

        #expect(PetCatalog.definitions.map(\.id) == allPetIDs)
        #expect(PetCatalog.builtInPetIDs == allPetIDs)

        #expect(PetCatalog.builtInCategories.count == 2)
        let cloudCategory = try #require(PetCatalog.builtInCategories.first)
        #expect(cloudCategory.id == "cloud-pets")
        #expect(cloudCategory.displayName == "Cloud Pets")
        #expect(cloudCategory.petIDs == cloudPetIDs)
        let tesslingCategory = PetCatalog.builtInCategories[1]
        #expect(tesslingCategory.id == "tesslings")
        #expect(tesslingCategory.displayName == "Tesslings")
        #expect(tesslingCategory.petIDs == tesslingPetIDs)
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

        #expect(PetCatalog.petIDs(for: .common) == [.cuteCloud, .nimbusCloud, .knotling])
        #expect(PetCatalog.petIDs(for: .rare) == [.cirrusCloud, .lenticularCloud, .prismite])
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
        for petID in [PetID.cuteCloud, .nimbusCloud, .cirrusCloud, .lenticularCloud, .snowCloud] {
            #expect(PetCatalog.pixelation(.chunky, allowedFor: petID) == .medium)
        }
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .knotling) == .chunky)
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .prismite) == .chunky)
        #expect(PetCatalog.pixelation(.chunky, allowedFor: PetID(rawValue: "helper-cloud")) == .medium)
    }
}
