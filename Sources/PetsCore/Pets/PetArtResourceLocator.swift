import Foundation

public enum PetArtResourceLocator {
    public static func url(for frame: PetAnimationFrame) -> URL? {
        Bundle.module.url(
            forResource: frame.resourceName,
            withExtension: frame.resourceExtension,
            subdirectory: frame.subdirectory
        )
    }
}
