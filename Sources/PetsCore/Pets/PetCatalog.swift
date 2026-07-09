public struct PetID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let cuteCloud = PetID(rawValue: "cute-cloud")
    public static let classicClaude = PetID(rawValue: "classic-claude")
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

    public static func custom(_ name: String) -> PetID {
        PetID(rawValue: "custom:\(name)")
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
    public static let builtInCategories: [PetCatalogCategory] = [
        PetCatalogCategory(
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
        )
    ]
    public static let builtInPetIDs: [PetID] = builtInCategories.flatMap(\.petIDs)

    public static func displayName(for petID: PetID) -> String {
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

    public static func category(for petID: PetID) -> PetCatalogCategory? {
        builtInCategories.first { $0.petIDs.contains(petID) }
    }

    public static func maximumPixelation(for petID: PetID) -> PetSpritePixelation {
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
        allowedFor petID: PetID
    ) -> PetSpritePixelation {
        min(requestedPixelation, maximumPixelation(for: petID))
    }
}
