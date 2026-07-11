public final class CuteCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .cuteCloud,
            displayName: "Cute Cloud",
            category: .cloudPets,
            maximumPixelation: .medium,
            legacyRenderFamily: .cuteCloud
        )
    }
}

public final class ClassicCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .classicCloud,
            displayName: "Classic Cloud",
            category: .cloudPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cloud
        )
    }
}

public final class HelperCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .helperCloud,
            displayName: "Helper Cloud",
            category: .cloudPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cloud
        )
    }
}

public final class SleepCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .sleepCloud,
            displayName: "Sleep Cloud",
            category: .cloudPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cloud
        )
    }
}

public final class FocusCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .focusCloud,
            displayName: "Focus Cloud",
            category: .cloudPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .cloud
        )
    }
}
