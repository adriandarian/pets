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
    func patchlingIdentifiersAndCategoryMetadataAreStable() {
        #expect(PetID.stitchback.rawValue == "stitchback")
        #expect(PetID.loppet.rawValue == "loppet")
        #expect(PetID.quiltwing.rawValue == "quiltwing")
        #expect(PetID.tasselpod.rawValue == "tasselpod")
        #expect(PetID.threadwyrm.rawValue == "threadwyrm")
        #expect(PetCategoryDescriptor.patchlings.id == "patchlings")
        #expect(PetCategoryDescriptor.patchlings.displayName == "Patchlings")
        #expect(PetCategoryDescriptor.patchlings.order == 2)
    }

    @Test
    func patchlingDefinitionsOwnTheirCatalogAndAnimationContracts() throws {
        let expected: [(PetID, String, PetRarity, PetDefinition.Type, PetMotionPreset)] = [
            (.stitchback, "Stitchback", .common, StitchbackPetDefinition.self, .breathe),
            (.loppet, "Loppet", .common, LoppetPetDefinition.self, .breathe),
            (.quiltwing, "Quiltwing", .rare, QuiltwingPetDefinition.self, .sway),
            (.tasselpod, "Tasselpod", .rare, TasselpodPetDefinition.self, .bob),
            (.threadwyrm, "Threadwyrm", .legendary, ThreadwyrmPetDefinition.self, .sway),
        ]

        for (petID, displayName, rarity, definitionType, idleMotion) in expected {
            let definition = try #require(PetCatalog.definition(for: petID))
            #expect(type(of: definition) == definitionType)
            #expect(definition.displayName == displayName)
            #expect(definition.rarity == rarity)
            #expect(definition.category == .patchlings)
            #expect(definition.capabilities.maximumPixelation == .medium)
            #expect(definition.capabilities.supportsStatusMoods)
            #expect(definition.capabilities.supportsHoverExcitement)
            #expect(definition.ambientEffect == .none)
            #expect(definition.defaults == .standard)
            guard case let .assetPack(pack) = definition.renderSource else {
                Issue.record("\(displayName) must use an asset pack")
                continue
            }
            #expect(pack.idle.frames.count == 8)
            #expect(pack.busy?.frames.count == 4)
            #expect(pack.waiting?.frames.count == 4)
            #expect(pack.excited?.frames.count == 5)
            #expect(pack.sleeping?.frames.count == 4)
            #expect(pack.completion == nil)
            #expect(pack.error == nil)
            #expect(pack.idle.motion == idleMotion)
            #expect(pack.busy?.motion == .bob)
            #expect(pack.waiting?.motion == .sway)
            #expect(pack.excited?.motion == .pulse)
            #expect(pack.sleeping?.motion == .breathe)
            #expect(pack.idle.frames.map(\.duration) == [
                1.70, 0.55, 0.50, 0.55, 1.35, 0.15, 0.15, 0.15,
            ])
            #expect(pack.waiting?.frames.map(\.duration) == [0.78, 0.54, 0.54, 0.78])
        }

        let stitchback = try #require(PetCatalog.definition(for: .stitchback))
        guard case let .assetPack(stitchbackPack) = stitchback.renderSource else {
            Issue.record("Stitchback must use an asset pack")
            return
        }
        #expect(abs(try #require(stitchbackPack.busy).frames[0].duration - 0.286) < 0.000_001)

        let loppet = try #require(PetCatalog.definition(for: .loppet))
        guard case let .assetPack(loppetPack) = loppet.renderSource else {
            Issue.record("Loppet must use an asset pack")
            return
        }
        #expect(abs(try #require(loppetPack.excited).frames[0].duration - 0.162) < 0.000_001)

        let quiltwing = try #require(PetCatalog.definition(for: .quiltwing))
        guard case let .assetPack(quiltwingPack) = quiltwing.renderSource else {
            Issue.record("Quiltwing must use an asset pack")
            return
        }
        #expect(abs(try #require(quiltwingPack.busy).frames[0].duration - 0.234) < 0.000_001)

        let tasselpod = try #require(PetCatalog.definition(for: .tasselpod))
        guard case let .assetPack(tasselpodPack) = tasselpod.renderSource else {
            Issue.record("Tasselpod must use an asset pack")
            return
        }
        #expect(abs(try #require(tasselpodPack.sleeping).frames[0].duration - 1.485) < 0.000_001)

        let threadwyrm = try #require(PetCatalog.definition(for: .threadwyrm))
        guard case let .assetPack(threadwyrmPack) = threadwyrm.renderSource else {
            Issue.record("Threadwyrm must use an asset pack")
            return
        }
        #expect(abs(try #require(threadwyrmPack.busy).frames[0].duration - 0.299) < 0.000_001)
        #expect(abs(try #require(threadwyrmPack.sleeping).frames[0].duration - 1.485) < 0.000_001)
    }

    @Test
    func mossboundIdentifiersAndCategoryMetadataAreStable() {
        #expect(PetID.huskroot.rawValue == "huskroot")
        #expect(PetID.fernstone.rawValue == "fernstone")
        #expect(PetID.knothollow.rawValue == "knothollow")
        #expect(PetID.bellbloom.rawValue == "bellbloom")
        #expect(PetID.glowcap.rawValue == "glowcap")
        #expect(PetCategoryDescriptor.mossbound.id == "mossbound")
        #expect(PetCategoryDescriptor.mossbound.displayName == "Mossbound")
        #expect(PetCategoryDescriptor.mossbound.order == 3)
    }

    @Test
    func mossboundDefinitionsOwnTheirCatalogAndAnimationContracts() throws {
        let expected: [(PetID, String, PetRarity, PetDefinition.Type)] = [
            (.huskroot, "Huskroot", .common, HuskrootPetDefinition.self),
            (.fernstone, "Fernstone", .common, FernstonePetDefinition.self),
            (.knothollow, "Knothollow", .rare, KnothollowPetDefinition.self),
            (.bellbloom, "Bellbloom", .rare, BellbloomPetDefinition.self),
            (.glowcap, "Glowcap", .legendary, GlowcapPetDefinition.self),
        ]

        for (petID, displayName, rarity, definitionType) in expected {
            let definition = try #require(PetCatalog.definition(for: petID))
            #expect(type(of: definition) == definitionType)
            #expect(definition.displayName == displayName)
            #expect(definition.rarity == rarity)
            #expect(definition.category == .mossbound)
            #expect(definition.capabilities.maximumPixelation == .chunky)
            #expect(definition.capabilities.supportsStatusMoods)
            #expect(definition.capabilities.supportsHoverExcitement)
            #expect(definition.ambientEffect == .lifeSparks)
            guard case let .assetPack(pack) = definition.renderSource else {
                Issue.record("\(displayName) must use an asset pack")
                continue
            }
            #expect(pack.idle.frames.count == 8)
            #expect(pack.busy?.frames.count == 4)
            #expect(pack.waiting?.frames.count == 4)
            #expect(pack.excited?.frames.count == 5)
            #expect(pack.sleeping?.frames.count == 4)
            #expect(pack.completion == nil)
            #expect(pack.error == nil)
        }
    }

    @Test
    func glowkinIdentifiersAndCategoryMetadataAreStable() {
        #expect(PetID.wicklet.rawValue == "wicklet")
        #expect(PetID.mosshell.rawValue == "mosshell")
        #expect(PetID.cometfin.rawValue == "cometfin")
        #expect(PetID.gleamwing.rawValue == "gleamwing")
        #expect(PetID.halora.rawValue == "halora")
        #expect(PetID.asterune.rawValue == "asterune")
        #expect(PetCategoryDescriptor.glowkin.id == "glowkin")
        #expect(PetCategoryDescriptor.glowkin.displayName == "Glowkin")
        #expect(PetCategoryDescriptor.glowkin.order == 4)
    }

    @Test
    func glowkinDefinitionsOwnTheirCatalogAndAnimationContracts() throws {
        let expected: [(PetID, String, PetRarity, PetDefinition.Type)] = [
            (.wicklet, "Wicklet", .common, WickletPetDefinition.self),
            (.mosshell, "Mosshell", .common, MosshellPetDefinition.self),
            (.cometfin, "Cometfin", .rare, CometfinPetDefinition.self),
            (.gleamwing, "Gleamwing", .rare, GleamwingPetDefinition.self),
            (.halora, "Halora", .legendary, HaloraPetDefinition.self),
            (.asterune, "Asterune", .legendary, AsterunePetDefinition.self),
        ]

        for (petID, displayName, rarity, definitionType) in expected {
            let definition = try #require(PetCatalog.definition(for: petID))
            #expect(type(of: definition) == definitionType)
            #expect(definition.displayName == displayName)
            #expect(definition.rarity == rarity)
            #expect(definition.category == .glowkin)
            #expect(definition.capabilities.maximumPixelation == .medium)
            #expect(definition.capabilities.supportsStatusMoods)
            #expect(definition.capabilities.supportsHoverExcitement)
            #expect(definition.ambientEffect == .none)
            guard case let .assetPack(pack) = definition.renderSource else {
                Issue.record("\(displayName) must use an asset pack")
                continue
            }
            #expect(pack.idle.frames.count == 8)
            #expect(pack.busy?.frames.count == 4)
            #expect(pack.waiting?.frames.count == 4)
            #expect(pack.excited?.frames.count == 5)
            #expect(pack.sleeping?.frames.count == 4)
            #expect(pack.completion == nil)
            #expect(pack.error == nil)
            #expect(pack.idle.frames.map(\.duration) == [
                1.60, 0.50, 0.45, 0.50, 1.20, 0.12, 0.12, 0.12,
            ])
            #expect(pack.excited?.frames.map(\.duration) == [0.18, 0.16, 0.16, 0.18, 0.28])
        }
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
    func orbitlingDefinitionOwnsItsCatalogAndAnimationContract() throws {
        let definition = try #require(PetCatalog.definition(for: .orbitling))
        #expect(definition is OrbitlingPetDefinition)
        #expect(definition.displayName == "Orbitling")
        #expect(definition.rarity == .legendary)
        #expect(definition.capabilities.maximumPixelation == .chunky)
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Orbitling must use an asset pack")
            return
        }
        #expect(pack.idle.frames.count == 8)
        #expect(pack.busy?.frames.count == 4)
        #expect(pack.waiting?.frames.count == 4)
        #expect(pack.excited?.frames.count == 5)
        #expect(pack.sleeping?.frames.count == 4)
    }

    @Test
    func registeredFamiliesIncludeCloudsTesslingsPatchlingsMossboundAndGlowkin() throws {
        let cloudPetIDs: [PetID] = [
            .cuteCloud,
            .nimbusCloud,
            .cirrusCloud,
            .lenticularCloud,
            .snowCloud,
        ]
        let tesslingPetIDs: [PetID] = [.knotling, .prismite, .orbitling]
        let patchlingPetIDs: [PetID] = [
            .stitchback,
            .loppet,
            .quiltwing,
            .tasselpod,
            .threadwyrm,
        ]
        let mossboundPetIDs: [PetID] = [
            .huskroot,
            .fernstone,
            .knothollow,
            .bellbloom,
            .glowcap,
        ]
        let glowkinPetIDs: [PetID] = [
            .wicklet,
            .mosshell,
            .cometfin,
            .gleamwing,
            .halora,
            .asterune,
        ]
        let allPetIDs = cloudPetIDs
            + tesslingPetIDs
            + patchlingPetIDs
            + mossboundPetIDs
            + glowkinPetIDs

        #expect(PetCatalog.definitions.map(\.id) == allPetIDs)
        #expect(PetCatalog.builtInPetIDs == allPetIDs)

        #expect(PetCatalog.builtInCategories.count == 5)
        let cloudCategory = try #require(PetCatalog.builtInCategories.first)
        #expect(cloudCategory.id == "cloud-pets")
        #expect(cloudCategory.displayName == "Cloud Pets")
        #expect(cloudCategory.petIDs == cloudPetIDs)
        let tesslingCategory = PetCatalog.builtInCategories[1]
        #expect(tesslingCategory.id == "tesslings")
        #expect(tesslingCategory.displayName == "Tesslings")
        #expect(tesslingCategory.petIDs == tesslingPetIDs)
        let patchlingCategory = PetCatalog.builtInCategories[2]
        #expect(patchlingCategory.id == "patchlings")
        #expect(patchlingCategory.displayName == "Patchlings")
        #expect(patchlingCategory.petIDs == patchlingPetIDs)
        let mossboundCategory = PetCatalog.builtInCategories[3]
        #expect(mossboundCategory.id == "mossbound")
        #expect(mossboundCategory.displayName == "Mossbound")
        #expect(mossboundCategory.petIDs == mossboundPetIDs)
        let glowkinCategory = PetCatalog.builtInCategories[4]
        #expect(glowkinCategory.id == "glowkin")
        #expect(glowkinCategory.displayName == "Glowkin")
        #expect(glowkinCategory.petIDs == glowkinPetIDs)
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

        #expect(PetCatalog.petIDs(for: .common) == [
            .cuteCloud,
            .nimbusCloud,
            .knotling,
            .stitchback,
            .loppet,
            .huskroot,
            .fernstone,
            .wicklet,
            .mosshell,
        ])
        #expect(PetCatalog.petIDs(for: .rare) == [
            .cirrusCloud,
            .lenticularCloud,
            .prismite,
            .quiltwing,
            .tasselpod,
            .knothollow,
            .bellbloom,
            .cometfin,
            .gleamwing,
        ])
        #expect(PetCatalog.petIDs(for: .legendary) == [
            .snowCloud,
            .orbitling,
            .threadwyrm,
            .glowcap,
            .halora,
            .asterune,
        ])
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
        #expect(PetCatalog.pixelation(.chunky, allowedFor: .orbitling) == .chunky)
        for petID in [
            PetID.stitchback,
            .loppet,
            .quiltwing,
            .tasselpod,
            .threadwyrm,
        ] {
            #expect(PetCatalog.pixelation(.chunky, allowedFor: petID) == .medium)
        }
        for petID in [
            PetID.huskroot,
            .fernstone,
            .knothollow,
            .bellbloom,
            .glowcap,
        ] {
            #expect(PetCatalog.pixelation(.chunky, allowedFor: petID) == .chunky)
        }
        for petID in [
            PetID.wicklet,
            .mosshell,
            .cometfin,
            .gleamwing,
            .halora,
            .asterune,
        ] {
            #expect(PetCatalog.pixelation(.chunky, allowedFor: petID) == .medium)
        }
        #expect(PetCatalog.pixelation(.chunky, allowedFor: PetID(rawValue: "helper-cloud")) == .medium)
    }
}
