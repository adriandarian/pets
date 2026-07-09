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

    public static func custom(_ name: String) -> ClaudePetID {
        ClaudePetID(rawValue: "custom:\(name)")
    }
}

public enum ClaudePetCatalog {
    public static let defaultPetID = ClaudePetID.cuteCloud
    public static let builtInPetIDs: [ClaudePetID] = [
        .cuteCloud,
        .classicClaude,
        .helperCloud,
        .sleepCloud,
        .focusCloud
    ]

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
        default:
            if petID.rawValue.hasPrefix("custom:") {
                return String(petID.rawValue.dropFirst("custom:".count))
            }
            return petID.rawValue
        }
    }

    public static func maximumPixelation(for petID: ClaudePetID) -> PetSpritePixelation {
        switch petID {
        case .cuteCloud:
            return .medium
        case .classicClaude, .helperCloud, .sleepCloud, .focusCloud:
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
