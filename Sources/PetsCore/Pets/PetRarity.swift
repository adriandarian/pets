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

    public var keyCost: Int {
        switch self {
        case .common: 1
        case .rare: 2
        case .legendary: 4
        }
    }
}
