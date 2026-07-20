import Foundation

public enum PetReleaseGiftTier: String, CaseIterable, Codable, Sendable {
    case routine
    case major
    case anniversary

    public var keyInventory: PetKeyInventory {
        switch self {
        case .routine:
            PetKeyInventory(common: 1)
        case .major:
            PetKeyInventory(common: 2)
        case .anniversary:
            PetKeyInventory(rare: 1)
        }
    }
}

public struct PetReleaseGift: Equatable, Sendable {
    public let version: String
    public let tier: PetReleaseGiftTier

    public init(version: String, tier: PetReleaseGiftTier) {
        self.version = version
        self.tier = tier
    }

    public var keyInventory: PetKeyInventory {
        tier.keyInventory
    }
}

public enum PetReleaseGiftPolicy {
    public static func gift(
        installedVersion: String?,
        configuredTier: String?
    ) -> PetReleaseGift? {
        guard var installedVersion else { return nil }
        installedVersion = installedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PetsVersion(installedVersion) != nil else { return nil }

        if installedVersion.first == "v" || installedVersion.first == "V" {
            installedVersion.removeFirst()
        }

        let normalizedTier = configuredTier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let tier = normalizedTier.flatMap(PetReleaseGiftTier.init(rawValue:)) ?? .routine
        return PetReleaseGift(version: installedVersion, tier: tier)
    }
}
