public final class SproutBuddyPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .sproutBuddy,
            displayName: "Sprout Buddy",
            category: .naturePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .nature
        )
    }
}

public final class PebblePalPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .pebblePal,
            displayName: "Pebble Pal",
            category: .naturePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .nature
        )
    }
}

public final class PocketStarPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .pocketStar,
            displayName: "Pocket Star",
            category: .naturePets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .nature
        )
    }
}
