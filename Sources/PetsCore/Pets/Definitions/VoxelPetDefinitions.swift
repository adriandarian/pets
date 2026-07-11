public final class VoxelCatPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .voxelCat,
            displayName: "Voxel Cat",
            category: .voxelPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .voxel
        )
    }
}

public final class VoxelSlimePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .voxelSlime,
            displayName: "Voxel Slime",
            category: .voxelPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .voxel
        )
    }
}

public final class VoxelDragonPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .voxelDragon,
            displayName: "Voxel Dragon",
            category: .voxelPets,
            maximumPixelation: .chunky,
            legacyRenderFamily: .voxel
        )
    }
}
