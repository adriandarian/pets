public struct PetID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let cuteCloud = PetID(rawValue: "cute-cloud")
    public static let nimbusCloud = PetID(rawValue: "nimbus-cloud")
    public static let cirrusCloud = PetID(rawValue: "cirrus-cloud")
    public static let lenticularCloud = PetID(rawValue: "lenticular-cloud")
    public static let snowCloud = PetID(rawValue: "snow-cloud")
    public static let knotling = PetID(rawValue: "knotling")
    public static let prismite = PetID(rawValue: "prismite")
    public static let orbitling = PetID(rawValue: "orbitling")
}

public struct PetCatalogCategory: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let petIDs: [PetID]

    public init(id: String, displayName: String, petIDs: [PetID]) {
        self.id = id
        self.displayName = displayName
        self.petIDs = petIDs
    }
}

public enum PetCatalog {
    public static let defaultPetID = PetID.cuteCloud
    public static let definitions: [PetDefinition] = [
        CumulusCloudPetDefinition(),
        NimbusCloudPetDefinition(),
        CirrusCloudPetDefinition(),
        LenticularCloudPetDefinition(),
        SnowCloudPetDefinition(),
    ]

    private static let definitionsByID = Dictionary(
        uniqueKeysWithValues: definitions.map { ($0.id, $0) }
    )

    public static let builtInCategories: [PetCatalogCategory] = [
        PetCatalogCategory(
            id: PetCategoryDescriptor.cloudPets.id,
            displayName: PetCategoryDescriptor.cloudPets.displayName,
            petIDs: [.cuteCloud, .nimbusCloud, .cirrusCloud, .lenticularCloud, .snowCloud]
        )
    ]
    public static let builtInPetIDs: [PetID] = builtInCategories.flatMap(\.petIDs)

    public static func resolvedPetID(_ petID: PetID) -> PetID {
        definitionsByID[petID] == nil ? defaultPetID : petID
    }

    public static func displayName(for petID: PetID) -> String {
        definition(for: resolvedPetID(petID))?.displayName ?? "Cumulus"
    }

    public static func category(for petID: PetID) -> PetCatalogCategory? {
        let resolvedID = resolvedPetID(petID)
        return builtInCategories.first { $0.petIDs.contains(resolvedID) }
    }

    public static func maximumPixelation(for petID: PetID) -> PetSpritePixelation {
        definition(for: resolvedPetID(petID))?.capabilities.maximumPixelation ?? .medium
    }

    public static func rarity(for petID: PetID) -> PetRarity {
        definition(for: resolvedPetID(petID))?.rarity ?? .common
    }

    public static func petIDs(for rarity: PetRarity) -> [PetID] {
        definitions.lazy.filter { $0.rarity == rarity }.map(\.id)
    }

    public static func definition(for petID: PetID) -> PetDefinition? {
        definitionsByID[petID]
    }

    public static func pixelation(
        _ requestedPixelation: PetSpritePixelation,
        allowedFor petID: PetID
    ) -> PetSpritePixelation {
        min(requestedPixelation, maximumPixelation(for: resolvedPetID(petID)))
    }
}
