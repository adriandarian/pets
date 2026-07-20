import Foundation

public enum PetChestArtResource: String, CaseIterable, Sendable {
    case common
    case rare
    case legendary
}

public enum PetOpenChestArtResource: String, CaseIterable, Sendable {
    case common = "common-open"
    case rare = "rare-open"
    case legendary = "legendary-open"
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

    public static func url(forOpenChest chest: PetOpenChestArtResource) -> URL? {
        Bundle.module.url(
            forResource: chest.rawValue,
            withExtension: "png",
            subdirectory: "PetArt/LootChests"
        )
    }
}
