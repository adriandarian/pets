import Foundation

public struct PetUsageReading: Equatable, Codable, Sendable {
    public let providerID: String
    public let periodID: String
    public let tokens: Int64

    public init(providerID: String, periodID: String, tokens: Int64) {
        self.providerID = providerID
        self.periodID = periodID
        self.tokens = max(0, tokens)
    }
}

public struct PetUsageCheckpoint: Equatable, Codable, Sendable {
    public let periodID: String
    public let observedTokens: Int64

    public init(periodID: String, observedTokens: Int64) {
        self.periodID = periodID
        self.observedTokens = max(0, observedTokens)
    }
}

public struct PetKeyInventory: Equatable, Codable, Sendable {
    public private(set) var common: Int
    public private(set) var rare: Int
    public private(set) var legendary: Int

    public init(common: Int = 0, rare: Int = 0, legendary: Int = 0) {
        self.common = max(0, common)
        self.rare = max(0, rare)
        self.legendary = max(0, legendary)
    }

    public init(rarity: PetRarity, count: Int) {
        self.init()
        add(max(0, count), to: rarity)
    }

    public func count(for rarity: PetRarity) -> Int {
        switch rarity {
        case .common: common
        case .rare: rare
        case .legendary: legendary
        }
    }

    fileprivate func normalized() -> PetKeyInventory {
        PetKeyInventory(common: common, rare: rare, legendary: legendary)
    }

    fileprivate mutating func add(_ count: Int, to rarity: PetRarity) {
        guard count > 0 else { return }
        switch rarity {
        case .common: common += count
        case .rare: rare += count
        case .legendary: legendary += count
        }
    }

    fileprivate mutating func remove(_ count: Int, from rarity: PetRarity) {
        guard count > 0 else { return }
        switch rarity {
        case .common: common -= count
        case .rare: rare -= count
        case .legendary: legendary -= count
        }
    }
}

public enum PetKeyUpgradeError: Error, Equatable, LocalizedError, Sendable {
    case insufficientKeys(rarity: PetRarity, required: Int)
    case highestRarity(PetRarity)

    public var errorDescription: String? {
        switch self {
        case let .insufficientKeys(rarity, required):
            "Upgrading needs \(required) \(rarity.displayName) Keys."
        case let .highestRarity(rarity):
            "\(rarity.displayName) Keys are already the highest rarity."
        }
    }
}

public enum PetChestOpenError: Error, Equatable, LocalizedError, Sendable {
    case insufficientKeys(rarity: PetRarity, required: Int)
    case allPetsCollected(rarity: PetRarity)

    public var errorDescription: String? {
        switch self {
        case let .insufficientKeys(rarity, required):
            "This chest needs \(required) \(rarity.displayName.lowercased()) \(required == 1 ? "key" : "keys")."
        case let .allPetsCollected(rarity):
            "Every \(rarity.displayName.lowercased()) pet is already collected."
        }
    }
}

public struct PetCollectionState: Equatable, Codable, Sendable {
    public static let rewardTokenThreshold: Int64 = 500_000_000

    public private(set) var ownedPetIDs: Set<PetID>
    public private(set) var keyInventory: PetKeyInventory
    public private(set) var tokenRemainder: Int64
    public private(set) var providerCheckpoints: [String: PetUsageCheckpoint]

    public init(
        ownedPetIDs: Set<PetID> = [.cuteCloud],
        keyInventory: PetKeyInventory = PetKeyInventory(),
        tokenRemainder: Int64 = 0,
        providerCheckpoints: [String: PetUsageCheckpoint] = [:]
    ) {
        self.ownedPetIDs = ownedPetIDs.union([.cuteCloud])
        self.keyInventory = keyInventory.normalized()
        self.tokenRemainder = max(0, tokenRemainder) % Self.rewardTokenThreshold
        self.providerCheckpoints = providerCheckpoints
    }

    public var progressFraction: Double {
        Double(tokenRemainder) / Double(Self.rewardTokenThreshold)
    }

    public var tokensUntilNextKey: Int64 {
        Self.rewardTokenThreshold - tokenRemainder
    }

    public func normalized(grandfathering petIDs: some Sequence<PetID>) -> PetCollectionState {
        var normalized = self
        normalized.ownedPetIDs.formUnion(petIDs)
        normalized.ownedPetIDs.insert(.cuteCloud)
        normalized.keyInventory = normalized.keyInventory.normalized()
        normalized.tokenRemainder = max(0, normalized.tokenRemainder) % Self.rewardTokenThreshold
        return normalized
    }

    @discardableResult
    public mutating func apply(_ reading: PetUsageReading) -> Int {
        let previous = providerCheckpoints[reading.providerID]
        let newlyObservedTokens: Int64

        if let previous, previous.periodID == reading.periodID {
            newlyObservedTokens = max(0, reading.tokens - previous.observedTokens)
            if reading.tokens > previous.observedTokens {
                providerCheckpoints[reading.providerID] = PetUsageCheckpoint(
                    periodID: reading.periodID,
                    observedTokens: reading.tokens
                )
            }
        } else {
            newlyObservedTokens = reading.tokens
            providerCheckpoints[reading.providerID] = PetUsageCheckpoint(
                periodID: reading.periodID,
                observedTokens: reading.tokens
            )
        }

        guard newlyObservedTokens > 0 else { return 0 }
        let total = tokenRemainder + newlyObservedTokens
        let earnedKeys = Int(total / Self.rewardTokenThreshold)
        tokenRemainder = total % Self.rewardTokenThreshold
        keyInventory.add(earnedKeys, to: .common)
        return earnedKeys
    }

    @discardableResult
    public mutating func upgradeKeys(from rarity: PetRarity) throws -> PetRarity {
        guard let nextRarity = rarity.nextRarity else {
            throw PetKeyUpgradeError.highestRarity(rarity)
        }
        guard keyInventory.count(for: rarity) >= PetRarity.keyUpgradeCost else {
            throw PetKeyUpgradeError.insufficientKeys(
                rarity: rarity,
                required: PetRarity.keyUpgradeCost
            )
        }

        keyInventory.remove(PetRarity.keyUpgradeCost, from: rarity)
        keyInventory.add(1, to: nextRarity)
        return nextRarity
    }

    public func unownedPetIDs(
        for rarity: PetRarity,
        eligiblePetIDs: [PetID]
    ) -> [PetID] {
        var seen: Set<PetID> = []
        return eligiblePetIDs.filter { petID in
            PetCatalog.rarity(for: petID) == rarity
                && !ownedPetIDs.contains(petID)
                && seen.insert(petID).inserted
        }
    }

    @discardableResult
    public mutating func openChest(
        rarity: PetRarity,
        eligiblePetIDs: [PetID],
        selectionIndex: Int
    ) throws -> PetID {
        let candidates = unownedPetIDs(for: rarity, eligiblePetIDs: eligiblePetIDs)
        guard !candidates.isEmpty else {
            throw PetChestOpenError.allPetsCollected(rarity: rarity)
        }
        guard keyInventory.count(for: rarity) >= 1 else {
            throw PetChestOpenError.insufficientKeys(rarity: rarity, required: 1)
        }

        let index = min(max(0, selectionIndex), candidates.count - 1)
        let unlockedPetID = candidates[index]
        keyInventory.remove(1, from: rarity)
        ownedPetIDs.insert(unlockedPetID)
        return unlockedPetID
    }

    private enum CodingKeys: String, CodingKey {
        case ownedPetIDs
        case keyInventory
        case keyCount
        case tokenRemainder
        case providerCheckpoints
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ownedPetIDs = try container.decodeIfPresent(Set<PetID>.self, forKey: .ownedPetIDs)
            ?? [.cuteCloud]
        let keyInventory: PetKeyInventory
        if let storedInventory = try container.decodeIfPresent(
            PetKeyInventory.self,
            forKey: .keyInventory
        ) {
            keyInventory = storedInventory
        } else {
            let legacyCommonKeys = try container.decodeIfPresent(Int.self, forKey: .keyCount) ?? 0
            keyInventory = PetKeyInventory(common: legacyCommonKeys)
        }
        let tokenRemainder = try container.decodeIfPresent(Int64.self, forKey: .tokenRemainder) ?? 0
        let providerCheckpoints = try container.decodeIfPresent(
            [String: PetUsageCheckpoint].self,
            forKey: .providerCheckpoints
        ) ?? [:]

        self.init(
            ownedPetIDs: ownedPetIDs,
            keyInventory: keyInventory,
            tokenRemainder: tokenRemainder,
            providerCheckpoints: providerCheckpoints
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownedPetIDs, forKey: .ownedPetIDs)
        try container.encode(keyInventory, forKey: .keyInventory)
        try container.encode(tokenRemainder, forKey: .tokenRemainder)
        try container.encode(providerCheckpoints, forKey: .providerCheckpoints)
    }
}
