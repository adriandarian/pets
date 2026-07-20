public enum PetSessionRouting {
    public static func sessions(
        _ sessions: [HarnessSession],
        trackedBy pet: PetInstance
    ) -> [HarnessSession] {
        guard !pet.trackingProviders.isEmpty else { return [] }
        let providerIDs = Set(pet.trackingProviders.map(\.rawValue))
        return sessions.filter { providerIDs.contains($0.harnessID) }
    }

    public static func dominantStatus(in sessions: [HarnessSession]) -> HarnessSessionStatus {
        if sessions.contains(where: { $0.status == .waiting }) {
            return .waiting
        }
        if sessions.contains(where: { $0.status == .busy }) {
            return .busy
        }
        return sessions.isEmpty ? .unknown : .idle
    }

    public static func reaction(
        _ reaction: PetReaction?,
        completedProviderIDs: Set<String>,
        for pet: PetInstance
    ) -> PetReaction? {
        guard reaction == .completion else { return reaction }
        let providerIDs = Set(pet.trackingProviders.map(\.rawValue))
        return providerIDs.isDisjoint(with: completedProviderIDs) ? nil : .completion
    }
}
