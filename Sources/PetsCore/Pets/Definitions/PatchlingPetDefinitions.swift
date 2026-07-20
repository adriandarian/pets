import Foundation

public final class StitchbackPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .stitchback,
            displayName: "Stitchback",
            rarity: .common,
            category: .patchlings,
            capabilities: .patchling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.96,
                anchorX: 0,
                anchorY: 2,
                shadowWidth: 86,
                shadowHeight: 12,
                shadowOpacity: 0.18,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                patchlingArtPack(
                    slug: "stitchback",
                    idleMotion: .breathe,
                    busyDurationScale: 1.10
                )
            )
        )
    }
}

public final class LoppetPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .loppet,
            displayName: "Loppet",
            rarity: .common,
            category: .patchlings,
            capabilities: .patchling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: 3,
                shadowWidth: 68,
                shadowHeight: 12,
                shadowOpacity: 0.17,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                patchlingArtPack(
                    slug: "loppet",
                    idleMotion: .breathe,
                    excitedDurationScale: 0.90
                )
            )
        )
    }
}

public final class QuiltwingPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .quiltwing,
            displayName: "Quiltwing",
            rarity: .rare,
            category: .patchlings,
            capabilities: .patchling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 94,
                shadowHeight: 10,
                shadowOpacity: 0.13,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                patchlingArtPack(
                    slug: "quiltwing",
                    idleMotion: .sway,
                    busyDurationScale: 0.90
                )
            )
        )
    }
}

public final class TasselpodPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .tasselpod,
            displayName: "Tasselpod",
            rarity: .rare,
            category: .patchlings,
            capabilities: .patchling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 76,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                patchlingArtPack(
                    slug: "tasselpod",
                    idleMotion: .bob,
                    sleepingDurationScale: 1.10
                )
            )
        )
    }
}

public final class ThreadwyrmPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .threadwyrm,
            displayName: "Threadwyrm",
            rarity: .legendary,
            category: .patchlings,
            capabilities: .patchling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 96,
                shadowHeight: 11,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                patchlingArtPack(
                    slug: "threadwyrm",
                    idleMotion: .sway,
                    busyDurationScale: 1.15,
                    sleepingDurationScale: 1.10
                )
            )
        )
    }
}

private extension PetCapabilities {
    static let patchling = PetCapabilities(
        maximumPixelation: .medium,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func patchlingArtPack(
    slug: String,
    idleMotion: PetMotionPreset,
    busyDurationScale: TimeInterval = 1,
    excitedDurationScale: TimeInterval = 1,
    sleepingDurationScale: TimeInterval = 1
) -> PetArtPack {
    PetArtPack(
        idle: patchlingAnimation(
            slug: slug,
            state: "idle",
            durations: [1.70, 0.55, 0.50, 0.55, 1.35, 0.15, 0.15, 0.15],
            blends: [0.18, 0.16, 0.16, 0.16, 0.14, 0.05, 0.05, 0.05],
            motion: idleMotion
        ),
        busy: patchlingAnimation(
            slug: slug,
            state: "busy",
            durations: scaled([0.26, 0.26, 0.26, 0.26], by: busyDurationScale),
            blends: scaled([0.08, 0.08, 0.08, 0.08], by: busyDurationScale),
            motion: .bob
        ),
        waiting: patchlingAnimation(
            slug: slug,
            state: "waiting",
            durations: [0.78, 0.54, 0.54, 0.78],
            blends: [0.16, 0.16, 0.16, 0.16],
            motion: .sway
        ),
        excited: patchlingAnimation(
            slug: slug,
            state: "excited",
            durations: scaled(
                [0.18, 0.16, 0.18, 0.20, 0.34],
                by: excitedDurationScale
            ),
            blends: scaled(
                [0.06, 0.06, 0.06, 0.06, 0.08],
                by: excitedDurationScale
            ),
            motion: .pulse
        ),
        sleeping: patchlingAnimation(
            slug: slug,
            state: "sleeping",
            durations: scaled(
                [1.35, 0.75, 0.75, 1.35],
                by: sleepingDurationScale
            ),
            blends: scaled(
                [0.18, 0.18, 0.18, 0.18],
                by: sleepingDurationScale
            ),
            motion: .breathe
        )
    )
}

private func scaled(
    _ values: [TimeInterval],
    by scale: TimeInterval
) -> [TimeInterval] {
    values.map { $0 * scale }
}

private func patchlingAnimation(
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
        preconditionFailure("Patchling animation configuration must be valid")
    }
    return animation
}
