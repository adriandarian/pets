public enum PetRarity: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case common
    case rare
    case legendary

    public var displayName: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .legendary: "Legendary"
        }
    }

    public static let keyUpgradeCost = 5

    public var nextRarity: PetRarity? {
        switch self {
        case .common: .rare
        case .rare: .legendary
        case .legendary: nil
        }
    }
}
