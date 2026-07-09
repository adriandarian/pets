public struct ClaudePetID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let cuteCloud = ClaudePetID(rawValue: "cute-cloud")
    public static let classicClaude = ClaudePetID(rawValue: "classic-claude")
    public static let helperCloud = ClaudePetID(rawValue: "helper-cloud")
    public static let sleepCloud = ClaudePetID(rawValue: "sleep-cloud")
    public static let focusCloud = ClaudePetID(rawValue: "focus-cloud")
    public static let codeBot = ClaudePetID(rawValue: "code-bot")
    public static let terminalCube = ClaudePetID(rawValue: "terminal-cube")
    public static let bookstackBuddy = ClaudePetID(rawValue: "bookstack-buddy")
    public static let sproutBuddy = ClaudePetID(rawValue: "sprout-buddy")
    public static let pebblePal = ClaudePetID(rawValue: "pebble-pal")
    public static let pocketStar = ClaudePetID(rawValue: "pocket-star")
    public static let teaCup = ClaudePetID(rawValue: "tea-cup")
    public static let nightLamp = ClaudePetID(rawValue: "night-lamp")
    public static let tinyRocket = ClaudePetID(rawValue: "tiny-rocket")

    public static func custom(_ name: String) -> ClaudePetID {
        ClaudePetID(rawValue: "custom:\(name)")
    }
}

public struct ClaudePetCatalogCategory: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let petIDs: [ClaudePetID]

    public init(id: String, displayName: String, petIDs: [ClaudePetID]) {
        self.id = id
        self.displayName = displayName
        self.petIDs = petIDs
    }
}

public enum ClaudePetCatalog {
    public static let defaultPetID = ClaudePetID.cuteCloud
    public static let builtInCategories: [ClaudePetCatalogCategory] = [
        ClaudePetCatalogCategory(
            id: "cloud-pets",
            displayName: "Cloud Pets",
            petIDs: [
                .cuteCloud,
                .classicClaude,
                .helperCloud,
                .sleepCloud,
                .focusCloud
            ]
        ),
        ClaudePetCatalogCategory(
            id: "workspace-pets",
            displayName: "Workspace Pets",
            petIDs: [
                .codeBot,
                .terminalCube,
                .bookstackBuddy
            ]
        ),
        ClaudePetCatalogCategory(
            id: "nature-pets",
            displayName: "Nature Pets",
            petIDs: [
                .sproutBuddy,
                .pebblePal,
                .pocketStar
            ]
        ),
        ClaudePetCatalogCategory(
            id: "cozy-pets",
            displayName: "Cozy Pets",
            petIDs: [
                .teaCup,
                .nightLamp,
                .tinyRocket
            ]
        )
    ]
    public static let builtInPetIDs: [ClaudePetID] = builtInCategories.flatMap(\.petIDs)

    public static func displayName(for petID: ClaudePetID) -> String {
        switch petID {
        case .cuteCloud:
            return "Cute Cloud"
        case .classicClaude:
            return "Classic Cloud"
        case .helperCloud:
            return "Helper Cloud"
        case .sleepCloud:
            return "Sleep Cloud"
        case .focusCloud:
            return "Focus Cloud"
        case .codeBot:
            return "Code Bot"
        case .terminalCube:
            return "Terminal Cube"
        case .bookstackBuddy:
            return "Bookstack Buddy"
        case .sproutBuddy:
            return "Sprout Buddy"
        case .pebblePal:
            return "Pebble Pal"
        case .pocketStar:
            return "Pocket Star"
        case .teaCup:
            return "Tea Cup"
        case .nightLamp:
            return "Night Lamp"
        case .tinyRocket:
            return "Tiny Rocket"
        default:
            if petID.rawValue.hasPrefix("custom:") {
                return String(petID.rawValue.dropFirst("custom:".count))
            }
            return petID.rawValue
        }
    }

    public static func category(for petID: ClaudePetID) -> ClaudePetCatalogCategory? {
        builtInCategories.first { $0.petIDs.contains(petID) }
    }

    public static func maximumPixelation(for petID: ClaudePetID) -> PetSpritePixelation {
        switch petID {
        case .cuteCloud:
            return .medium
        case .classicClaude, .helperCloud, .sleepCloud, .focusCloud,
             .codeBot, .terminalCube, .bookstackBuddy,
             .sproutBuddy, .pebblePal, .pocketStar,
             .teaCup, .nightLamp, .tinyRocket:
            return .chunky
        default:
            return .off
        }
    }

    public static func pixelation(
        _ requestedPixelation: PetSpritePixelation,
        allowedFor petID: ClaudePetID
    ) -> PetSpritePixelation {
        min(requestedPixelation, maximumPixelation(for: petID))
    }
}
