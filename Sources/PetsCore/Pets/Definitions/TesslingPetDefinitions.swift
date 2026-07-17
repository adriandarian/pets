import Foundation

public final class KnotlingPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .knotling,
            displayName: "Knotling",
            rarity: .common,
            category: .tesslings,
            capabilities: .tessling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 78,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(tesslingArtPack(slug: "knotling"))
        )
    }
}

public final class PrismitePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .prismite,
            displayName: "Prismite",
            rarity: .rare,
            category: .tesslings,
            capabilities: .tessling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.93,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 84,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(tesslingArtPack(slug: "prismite"))
        )
    }
}

private extension PetCapabilities {
    static let tessling = PetCapabilities(
        maximumPixelation: .chunky,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func tesslingArtPack(slug: String) -> PetArtPack {
    PetArtPack(
        idle: tesslingAnimation(
            slug: slug,
            state: "idle",
            durations: [1.60, 0.50, 0.45, 0.50, 1.20, 0.12, 0.12, 0.12],
            blends: [0.18, 0.16, 0.16, 0.16, 0.12, 0.04, 0.04, 0.04],
            motion: .breathe
        ),
        busy: tesslingAnimation(
            slug: slug,
            state: "busy",
            durations: [0.22, 0.22, 0.22, 0.22],
            blends: [0.08, 0.08, 0.08, 0.08],
            motion: .bob
        ),
        waiting: tesslingAnimation(
            slug: slug,
            state: "waiting",
            durations: [0.70, 0.55, 0.55, 0.70],
            blends: [0.16, 0.16, 0.16, 0.16],
            motion: .sway
        ),
        excited: tesslingAnimation(
            slug: slug,
            state: "excited",
            durations: [0.18, 0.16, 0.16, 0.18, 0.28],
            blends: [0.06, 0.06, 0.06, 0.06, 0.08],
            motion: .pulse
        ),
        sleeping: tesslingAnimation(
            slug: slug,
            state: "sleeping",
            durations: [1.30, 0.75, 0.75, 1.30],
            blends: [0.18, 0.18, 0.18, 0.18],
            motion: .breathe
        )
    )
}

private func tesslingAnimation(
    slug: String,
    state: String,
    durations: [TimeInterval],
    blends: [TimeInterval],
    motion: PetMotionPreset
) -> PetAnimation {
    precondition(durations.count == blends.count)
    let frames = durations.indices.map { index in
        PetAnimationFrame(
            resourceName: String(format: "frame-%03d", index),
            resourceExtension: "png",
            subdirectory: "PetArt/\(slug)/\(state)",
            duration: durations[index],
            blendDuration: blends[index]
        )
    }
    guard let animation = PetAnimation(
        frames: frames,
        loopBehavior: .loop,
        motion: motion
    ) else {
        preconditionFailure("Tessling animation configuration must be valid")
    }
    return animation
}
