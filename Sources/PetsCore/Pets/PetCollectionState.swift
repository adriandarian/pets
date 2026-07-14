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

public enum PetChestOpenError: Error, Equatable, LocalizedError, Sendable {
    case insufficientKeys(required: Int)
    case allPetsCollected(rarity: PetRarity)

    public var errorDescription: String? {
        switch self {
        case let .insufficientKeys(required):
            "This chest needs \(required) \(required == 1 ? "key" : "keys")."
        case let .allPetsCollected(rarity):
            "Every \(rarity.displayName.lowercased()) pet is already collected."
        }
    }
}

public struct PetCollectionState: Equatable, Codable, Sendable {
    public static let rewardTokenThreshold: Int64 = 500_000_000

    public private(set) var ownedPetIDs: Set<PetID>
    public private(set) var keyCount: Int
    public private(set) var tokenRemainder: Int64
    public private(set) var providerCheckpoints: [String: PetUsageCheckpoint]

    public init(
        ownedPetIDs: Set<PetID> = [.cuteCloud],
        keyCount: Int = 0,
        tokenRemainder: Int64 = 0,
        providerCheckpoints: [String: PetUsageCheckpoint] = [:]
    ) {
        self.ownedPetIDs = ownedPetIDs.union([.cuteCloud])
        self.keyCount = max(0, keyCount)
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
        normalized.keyCount = max(0, normalized.keyCount)
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
        keyCount += earnedKeys
        return earnedKeys
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
        guard keyCount >= rarity.keyCost else {
            throw PetChestOpenError.insufficientKeys(required: rarity.keyCost)
        }

        let index = min(max(0, selectionIndex), candidates.count - 1)
        let unlockedPetID = candidates[index]
        keyCount -= rarity.keyCost
        ownedPetIDs.insert(unlockedPetID)
        return unlockedPetID
    }
}
