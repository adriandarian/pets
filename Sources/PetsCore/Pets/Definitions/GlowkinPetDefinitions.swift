import Foundation

public final class WickletPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .wicklet,
            displayName: "Wicklet",
            rarity: .common,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 72,
                shadowHeight: 11,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "wicklet",
                    idleMotion: .breathe,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class MosshellPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .mosshell,
            displayName: "Mosshell",
            rarity: .common,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.95,
                anchorX: 0,
                anchorY: 2,
                shadowWidth: 84,
                shadowHeight: 12,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "mosshell",
                    idleMotion: .breathe,
                    busyMotion: .sway,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class CometfinPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .cometfin,
            displayName: "Cometfin",
            rarity: .rare,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 96,
                shadowHeight: 10,
                shadowOpacity: 0.13,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "cometfin",
                    idleMotion: .sway,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class GleamwingPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .gleamwing,
            displayName: "Gleamwing",
            rarity: .rare,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 102,
                shadowHeight: 10,
                shadowOpacity: 0.12,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "gleamwing",
                    idleMotion: .bob,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class HaloraPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .halora,
            displayName: "Halora",
            rarity: .legendary,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.89,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 86,
                shadowHeight: 10,
                shadowOpacity: 0.12,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "halora",
                    idleMotion: .bob,
                    busyMotion: .breathe,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class AsterunePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .asterune,
            displayName: "Asterune",
            rarity: .legendary,
            category: .glowkin,
            capabilities: .glowkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 88,
                shadowHeight: 10,
                shadowOpacity: 0.12,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                glowkinArtPack(
                    slug: "asterune",
                    idleMotion: .breathe,
                    busyMotion: .sway,
                    waitingMotion: .sway
                )
            )
        )
    }
}

private extension PetCapabilities {
    static let glowkin = PetCapabilities(
        maximumPixelation: .medium,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func glowkinArtPack(
    slug: String,
    idleMotion: PetMotionPreset,
    busyMotion: PetMotionPreset,
    waitingMotion: PetMotionPreset
) -> PetArtPack {
    PetArtPack(
        idle: glowkinAnimation(
            slug: slug,
            state: "idle",
            durations: [1.60, 0.50, 0.45, 0.50, 1.20, 0.12, 0.12, 0.12],
            blends: [0.18, 0.16, 0.16, 0.16, 0.12, 0.04, 0.04, 0.04],
            motion: idleMotion
        ),
        busy: glowkinAnimation(
            slug: slug,
            state: "busy",
            durations: [0.22, 0.22, 0.22, 0.22],
            blends: [0.08, 0.08, 0.08, 0.08],
            motion: busyMotion
        ),
        waiting: glowkinAnimation(
            slug: slug,
            state: "waiting",
            durations: [0.70, 0.55, 0.55, 0.70],
            blends: [0.16, 0.16, 0.16, 0.16],
            motion: waitingMotion
        ),
        excited: glowkinAnimation(
            slug: slug,
            state: "excited",
            durations: [0.18, 0.16, 0.16, 0.18, 0.28],
            blends: [0.06, 0.06, 0.06, 0.06, 0.08],
            motion: .pulse
        ),
        sleeping: glowkinAnimation(
            slug: slug,
            state: "sleeping",
            durations: [1.30, 0.75, 0.75, 1.30],
            blends: [0.18, 0.18, 0.18, 0.18],
            motion: .breathe
        )
    )
}

private func glowkinAnimation(
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
        preconditionFailure("Glowkin animation configuration must be valid")
    }
    return animation
}
