import Foundation

public enum PetChestArtResource: String, CaseIterable, Sendable {
    case common
    case rare
    case legendary
}

public enum PetArtResourceLocator {
    public static func url(for frame: PetAnimationFrame) -> URL? {
        Bundle.module.url(
            forResource: frame.resourceName,
            withExtension: frame.resourceExtension,
            subdirectory: frame.subdirectory
        )
    }

    public static func url(for chest: PetChestArtResource) -> URL? {
        Bundle.module.url(
            forResource: chest.rawValue,
            withExtension: "png",
            subdirectory: "PetArt/LootChests"
        )
    }
}
