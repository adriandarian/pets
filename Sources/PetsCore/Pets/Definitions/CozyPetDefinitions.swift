public final class TeaCupPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .teaCup,
            displayName: "Tea Cup",
            category: .cozyPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cozy
        )
    }
}

public final class NightLampPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .nightLamp,
            displayName: "Night Lamp",
            category: .cozyPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cozy
        )
    }
}

public final class TinyRocketPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .tinyRocket,
            displayName: "Tiny Rocket",
            category: .cozyPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cozy
        )
    }
}
