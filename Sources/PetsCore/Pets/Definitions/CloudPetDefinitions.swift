import Foundation

public final class CumulusCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        let artPack = PetArtPack(
            idle: cloudIdleAnimation(slug: "cute-cloud", motion: .breathe),
            busy: cloudAnimation(slug: "cute-cloud", state: "busy", duration: 0.72, motion: .bob),
            waiting: cloudAnimation(slug: "cute-cloud", state: "waiting", duration: 0.85, motion: .sway),
            excited: cloudAnimation(slug: "cute-cloud", state: "excited", duration: 0.55, motion: .pulse),
            sleeping: cloudAnimation(slug: "cute-cloud", state: "sleeping", duration: 1.4, motion: .breathe)
        )
        super.init(
            id: .cuteCloud,
            displayName: "Cumulus",
            category: .cloudPets,
            capabilities: .cloudWithMoods,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 1,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 76,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(artPack)
        )
    }
}

public final class NimbusCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .nimbusCloud,
            displayName: "Nimbus",
            category: .cloudPets,
            capabilities: .cloudWithoutMoods,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: -1,
                shadowWidth: 64,
                shadowHeight: 10,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                PetArtPack(idle: cloudIdleAnimation(slug: "nimbus-cloud", motion: .bob))
            )
        )
    }
}

public final class CirrusCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .cirrusCloud,
            displayName: "Cirrus",
            category: .cloudPets,
            capabilities: .cloudWithoutMoods,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.96,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 82,
                shadowHeight: 9,
                shadowOpacity: 0.13,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                PetArtPack(idle: cloudAnimation(slug: "cirrus-cloud", motion: .sway))
            )
        )
    }
}

public final class LenticularCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .lenticularCloud,
            displayName: "Lenticular",
            category: .cloudPets,
            capabilities: .cloudWithoutMoods,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.96,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 86,
                shadowHeight: 10,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                PetArtPack(idle: cloudAnimation(slug: "lenticular-cloud", motion: .breathe))
            )
        )
    }
}

public final class SnowCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .snowCloud,
            displayName: "Snow Cloud",
            category: .cloudPets,
            capabilities: .cloudWithoutMoods,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 78,
                shadowHeight: 10,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                PetArtPack(idle: cloudAnimation(slug: "snow-cloud", motion: .breathe))
            )
        )
    }
}

private extension PetCapabilities {
    static let cloudWithMoods = PetCapabilities(
        maximumPixelation: .medium,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )

    static let cloudWithoutMoods = PetCapabilities(
        maximumPixelation: .medium,
        supportsStatusMoods: false,
        supportsHoverExcitement: true
    )
}

private let cloudIdleFrameTiming: [(duration: TimeInterval, blend: TimeInterval)] = [
    (2.00, 0.22),
    (0.65, 0.18),
    (0.55, 0.20),
    (0.65, 0.18),
    (1.45, 0.12),
    (0.08, 0.04),
    (0.10, 0.04),
    (0.08, 0.04),
]

private func cloudIdleAnimation(slug: String, motion: PetMotionPreset) -> PetAnimation {
    let frames = cloudIdleFrameTiming.enumerated().map { index, timing in
        PetAnimationFrame(
            resourceName: String(format: "frame-%03d", index),
            resourceExtension: "png",
            subdirectory: "PetArt/\(slug)/idle",
            duration: timing.duration,
            blendDuration: timing.blend
        )
    }
    guard let animation = PetAnimation(frames: frames, loopBehavior: .loop, motion: motion) else {
        preconditionFailure("Cloud idle animation must contain valid frames")
    }
    return animation
}

private func cloudAnimation(
    slug: String,
    state: String = "idle",
    duration: TimeInterval = 1.1,
    motion: PetMotionPreset = .breathe
) -> PetAnimation {
    guard let animation = PetAnimation(
        frames: [
            PetAnimationFrame(
                resourceName: "frame-000",
                resourceExtension: "png",
                subdirectory: "PetArt/\(slug)/\(state)",
                duration: duration
            )
        ],
        loopBehavior: .loop,
        motion: motion
    ) else {
        preconditionFailure("Cloud animation must contain a valid frame")
    }
    return animation
}
