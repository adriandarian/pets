public enum PetSpritePixelation: String, CaseIterable, Codable, Comparable, Sendable {
    case off
    case subtle
    case medium
    case chunky

    public static func < (lhs: PetSpritePixelation, rhs: PetSpritePixelation) -> Bool {
        lhs.rank < rhs.rank
    }

    public static func persisted(rawValue: String?) -> PetSpritePixelation {
        guard let rawValue, let pixelation = PetSpritePixelation(rawValue: rawValue) else {
            return .off
        }
        return pixelation
    }

    public var displayName: String {
        switch self {
        case .off:
            return "Smooth"
        case .subtle:
            return "Subtle Pixels"
        case .medium:
            return "Medium Pixels"
        case .chunky:
            return "Chunky Pixels"
        }
    }

    public var renderScale: Double {
        switch self {
        case .off:
            return 1.0
        case .subtle:
            return 1.6
        case .medium:
            return 2.2
        case .chunky:
            return 3.0
        }
    }

    private var rank: Int {
        switch self {
        case .off:
            return 0
        case .subtle:
            return 1
        case .medium:
            return 2
        case .chunky:
            return 3
        }
    }
}
