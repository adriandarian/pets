public struct PetID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue == "classic-claude" ? "classic-cloud" : rawValue
    }

    public static let cuteCloud = PetID(rawValue: "cute-cloud")
    public static let classicCloud = PetID(rawValue: "classic-cloud")
    public static let helperCloud = PetID(rawValue: "helper-cloud")
    public static let sleepCloud = PetID(rawValue: "sleep-cloud")
    public static let focusCloud = PetID(rawValue: "focus-cloud")
    public static let codeBot = PetID(rawValue: "code-bot")
    public static let terminalCube = PetID(rawValue: "terminal-cube")
    public static let bookstackBuddy = PetID(rawValue: "bookstack-buddy")
    public static let sproutBuddy = PetID(rawValue: "sprout-buddy")
    public static let pebblePal = PetID(rawValue: "pebble-pal")
    public static let pocketStar = PetID(rawValue: "pocket-star")
    public static let teaCup = PetID(rawValue: "tea-cup")
    public static let nightLamp = PetID(rawValue: "night-lamp")
    public static let tinyRocket = PetID(rawValue: "tiny-rocket")
    public static let voxelCat = PetID(rawValue: "voxel-cat")
    public static let voxelSlime = PetID(rawValue: "voxel-slime")
    public static let voxelDragon = PetID(rawValue: "voxel-dragon")

    public static func custom(_ name: String) -> PetID {
        PetID(rawValue: "custom:\(name)")
    }
}

public enum PetRenderFamily: Equatable, Hashable, Sendable {
    case cuteCloud
    case cloud
    case workspace
    case nature
    case cozy
    case voxel
}

public struct PetCatalogEntry: Equatable, Hashable, Sendable {
    public let id: PetID
    public let displayName: String
    public let categoryID: String
    public let renderFamily: PetRenderFamily
    public let maximumPixelation: PetSpritePixelation

    public init(
        id: PetID,
        displayName: String,
        categoryID: String,
        renderFamily: PetRenderFamily,
        maximumPixelation: PetSpritePixelation
    ) {
        self.id = id
        self.displayName = displayName
        self.categoryID = categoryID
        self.renderFamily = renderFamily
        self.maximumPixelation = maximumPixelation
    }
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
        CuteCloudPetDefinition(),
        ClassicCloudPetDefinition(),
        HelperCloudPetDefinition(),
        SleepCloudPetDefinition(),
        FocusCloudPetDefinition(),
        CodeBotPetDefinition(),
        TerminalCubePetDefinition(),
        BookstackBuddyPetDefinition(),
        SproutBuddyPetDefinition(),
        PebblePalPetDefinition(),
        PocketStarPetDefinition(),
        TeaCupPetDefinition(),
        NightLampPetDefinition(),
        TinyRocketPetDefinition(),
        VoxelCatPetDefinition(),
        VoxelSlimePetDefinition(),
        VoxelDragonPetDefinition()
    ]

    private static let definitionsByID = Dictionary(
        uniqueKeysWithValues: definitions.map { ($0.id, $0) }
    )

    public static let entries: [PetCatalogEntry] = definitions.compactMap { definition in
        guard case let .legacy(renderFamily) = definition.renderSource else { return nil }
        return PetCatalogEntry(
            id: definition.id,
            displayName: definition.displayName,
            categoryID: definition.category.id,
            renderFamily: renderFamily,
            maximumPixelation: definition.capabilities.maximumPixelation
        )
    }

    public static let builtInCategories: [PetCatalogCategory] = {
        let groupedDefinitions = Dictionary(grouping: definitions, by: \.category)
        return groupedDefinitions.keys.sorted { $0.order < $1.order }.map { category in
            PetCatalogCategory(
                id: category.id,
                displayName: category.displayName,
                petIDs: groupedDefinitions[category, default: []].map(\.id)
            )
        }
    }()
    public static let builtInPetIDs: [PetID] = builtInCategories.flatMap(\.petIDs)

    public static func displayName(for petID: PetID) -> String {
        if let definition = definition(for: petID) {
            return definition.displayName
        }
        if petID.rawValue.hasPrefix("custom:") {
            return String(petID.rawValue.dropFirst("custom:".count))
        }
        return petID.rawValue
    }

    public static func category(for petID: PetID) -> PetCatalogCategory? {
        builtInCategories.first { $0.petIDs.contains(petID) }
    }

    public static func maximumPixelation(for petID: PetID) -> PetSpritePixelation {
        definition(for: petID)?.capabilities.maximumPixelation ?? .off
    }

    public static func renderFamily(for petID: PetID) -> PetRenderFamily? {
        guard case let .legacy(renderFamily) = definition(for: petID)?.renderSource else { return nil }
        return renderFamily
    }

    public static func entry(for petID: PetID) -> PetCatalogEntry? {
        entries.first { $0.id == petID }
    }

    public static func definition(for petID: PetID) -> PetDefinition? {
        definitionsByID[petID]
    }

    public static func pixelation(
        _ requestedPixelation: PetSpritePixelation,
        allowedFor petID: PetID
    ) -> PetSpritePixelation {
        min(requestedPixelation, maximumPixelation(for: petID))
    }
}
