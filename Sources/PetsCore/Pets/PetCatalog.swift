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
    public static let entries: [PetCatalogEntry] = [
        PetCatalogEntry(
            id: .cuteCloud,
            displayName: "Cute Cloud",
            categoryID: "cloud-pets",
            renderFamily: .cuteCloud,
            maximumPixelation: .medium
        ),
        PetCatalogEntry(
            id: .classicCloud,
            displayName: "Classic Cloud",
            categoryID: "cloud-pets",
            renderFamily: .cloud,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .helperCloud,
            displayName: "Helper Cloud",
            categoryID: "cloud-pets",
            renderFamily: .cloud,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .sleepCloud,
            displayName: "Sleep Cloud",
            categoryID: "cloud-pets",
            renderFamily: .cloud,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .focusCloud,
            displayName: "Focus Cloud",
            categoryID: "cloud-pets",
            renderFamily: .cloud,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .codeBot,
            displayName: "Code Bot",
            categoryID: "workspace-pets",
            renderFamily: .workspace,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .terminalCube,
            displayName: "Terminal Cube",
            categoryID: "workspace-pets",
            renderFamily: .workspace,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .bookstackBuddy,
            displayName: "Bookstack Buddy",
            categoryID: "workspace-pets",
            renderFamily: .workspace,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .sproutBuddy,
            displayName: "Sprout Buddy",
            categoryID: "nature-pets",
            renderFamily: .nature,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .pebblePal,
            displayName: "Pebble Pal",
            categoryID: "nature-pets",
            renderFamily: .nature,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .pocketStar,
            displayName: "Pocket Star",
            categoryID: "nature-pets",
            renderFamily: .nature,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .teaCup,
            displayName: "Tea Cup",
            categoryID: "cozy-pets",
            renderFamily: .cozy,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .nightLamp,
            displayName: "Night Lamp",
            categoryID: "cozy-pets",
            renderFamily: .cozy,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .tinyRocket,
            displayName: "Tiny Rocket",
            categoryID: "cozy-pets",
            renderFamily: .cozy,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .voxelCat,
            displayName: "Voxel Cat",
            categoryID: "voxel-pets",
            renderFamily: .voxel,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .voxelSlime,
            displayName: "Voxel Slime",
            categoryID: "voxel-pets",
            renderFamily: .voxel,
            maximumPixelation: .chunky
        ),
        PetCatalogEntry(
            id: .voxelDragon,
            displayName: "Voxel Dragon",
            categoryID: "voxel-pets",
            renderFamily: .voxel,
            maximumPixelation: .chunky
        )
    ]

    public static let builtInCategories: [PetCatalogCategory] = [
        PetCatalogCategory(
            id: "cloud-pets",
            displayName: "Cloud Pets",
            petIDs: [
                .cuteCloud,
                .classicCloud,
                .helperCloud,
                .sleepCloud,
                .focusCloud
            ]
        ),
        PetCatalogCategory(
            id: "workspace-pets",
            displayName: "Workspace Pets",
            petIDs: [
                .codeBot,
                .terminalCube,
                .bookstackBuddy
            ]
        ),
        PetCatalogCategory(
            id: "nature-pets",
            displayName: "Nature Pets",
            petIDs: [
                .sproutBuddy,
                .pebblePal,
                .pocketStar
            ]
        ),
        PetCatalogCategory(
            id: "cozy-pets",
            displayName: "Cozy Pets",
            petIDs: [
                .teaCup,
                .nightLamp,
                .tinyRocket
            ]
        ),
        PetCatalogCategory(
            id: "voxel-pets",
            displayName: "Voxel Pets",
            petIDs: [
                .voxelCat,
                .voxelSlime,
                .voxelDragon
            ]
        )
    ]
    public static let builtInPetIDs: [PetID] = builtInCategories.flatMap(\.petIDs)

    public static func displayName(for petID: PetID) -> String {
        if let entry = entry(for: petID) {
            return entry.displayName
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
        entry(for: petID)?.maximumPixelation ?? .off
    }

    public static func renderFamily(for petID: PetID) -> PetRenderFamily? {
        entry(for: petID)?.renderFamily
    }

    public static func entry(for petID: PetID) -> PetCatalogEntry? {
        entries.first { $0.id == petID }
    }

    public static func pixelation(
        _ requestedPixelation: PetSpritePixelation,
        allowedFor petID: PetID
    ) -> PetSpritePixelation {
        min(requestedPixelation, maximumPixelation(for: petID))
    }
}
