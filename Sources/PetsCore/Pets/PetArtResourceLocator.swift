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
    private static let resourceBundle: Bundle = {
        let packagedBundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("Pets_PetsCore.bundle", isDirectory: true)

        if let packagedBundleURL,
           let packagedBundle = Bundle(url: packagedBundleURL) {
            return packagedBundle
        }

        return Bundle.module
    }()

    public static func url(for frame: PetAnimationFrame) -> URL? {
        resourceBundle.url(
            forResource: frame.resourceName,
            withExtension: frame.resourceExtension,
            subdirectory: frame.subdirectory
        )
    }

    public static func url(for chest: PetChestArtResource) -> URL? {
        resourceBundle.url(
            forResource: chest.rawValue,
            withExtension: "png",
            subdirectory: "PetArt/LootChests"
        )
    }

    public static func url(forOpenChest chest: PetOpenChestArtResource) -> URL? {
        resourceBundle.url(
            forResource: chest.rawValue,
            withExtension: "png",
            subdirectory: "PetArt/LootChests"
        )
    }
}
