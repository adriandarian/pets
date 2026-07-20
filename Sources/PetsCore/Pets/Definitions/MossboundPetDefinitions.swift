import Foundation

public final class HuskrootPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .huskroot,
            displayName: "Huskroot",
            rarity: .common,
            category: .mossbound,
            capabilities: .mossbound,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.93,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 64,
                shadowHeight: 11,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            ambientEffect: .lifeSparks,
            renderSource: .assetPack(mossboundArtPack(slug: "huskroot"))
        )
    }
}

public final class FernstonePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .fernstone,
            displayName: "Fernstone",
            rarity: .common,
            category: .mossbound,
            capabilities: .mossbound,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 3,
                shadowWidth: 92,
                shadowHeight: 13,
                shadowOpacity: 0.17,
                transitionDuration: 0.16
            ),
            ambientEffect: .lifeSparks,
            renderSource: .assetPack(mossboundArtPack(slug: "fernstone"))
        )
    }
}

public final class KnothollowPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .knothollow,
            displayName: "Knothollow",
            rarity: .rare,
            category: .mossbound,
            capabilities: .mossbound,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.86,
                anchorX: 0,
                anchorY: 4,
                shadowWidth: 104,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            ambientEffect: .lifeSparks,
            renderSource: .assetPack(mossboundArtPack(slug: "knothollow"))
        )
    }
}

public final class BellbloomPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .bellbloom,
            displayName: "Bellbloom",
            rarity: .rare,
            category: .mossbound,
            capabilities: .mossbound,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.91,
                anchorX: 0,
                anchorY: -1,
                shadowWidth: 54,
                shadowHeight: 8,
                shadowOpacity: 0.12,
                transitionDuration: 0.16
            ),
            ambientEffect: .lifeSparks,
            renderSource: .assetPack(mossboundArtPack(slug: "bellbloom"))
        )
    }
}

public final class GlowcapPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .glowcap,
            displayName: "Glowcap",
            rarity: .legendary,
            category: .mossbound,
            capabilities: .mossbound,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: -1,
                shadowWidth: 66,
                shadowHeight: 9,
                shadowOpacity: 0.13,
                transitionDuration: 0.16
            ),
            ambientEffect: .lifeSparks,
            renderSource: .assetPack(mossboundArtPack(slug: "glowcap"))
        )
    }
}

private extension PetCapabilities {
    static let mossbound = PetCapabilities(
        maximumPixelation: .chunky,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func mossboundArtPack(slug: String) -> PetArtPack {
    PetArtPack(
        idle: mossboundAnimation(
            slug: slug,
            state: "idle",
            durations: [1.70, 0.48, 0.42, 0.48, 1.10, 0.10, 0.12, 0.10],
            blends: [0.18, 0.14, 0.14, 0.14, 0.10, 0.04, 0.04, 0.04],
            motion: .breathe
        ),
        busy: mossboundAnimation(
            slug: slug,
            state: "busy",
            durations: [0.24, 0.24, 0.24, 0.24],
            blends: [0.08, 0.08, 0.08, 0.08],
            motion: .bob
        ),
        waiting: mossboundAnimation(
            slug: slug,
            state: "waiting",
            durations: [0.70, 0.52, 0.52, 0.70],
            blends: [0.14, 0.14, 0.14, 0.14],
            motion: .sway
        ),
        excited: mossboundAnimation(
            slug: slug,
            state: "excited",
            durations: [0.16, 0.14, 0.14, 0.16, 0.30],
            blends: [0.05, 0.05, 0.05, 0.05, 0.08],
            motion: .pulse
        ),
        sleeping: mossboundAnimation(
            slug: slug,
            state: "sleeping",
            durations: [1.40, 0.80, 0.80, 1.40],
            blends: [0.18, 0.18, 0.18, 0.18],
            motion: .breathe
        )
    )
}

private func mossboundAnimation(
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
        preconditionFailure("Mossbound animation configuration must be valid")
    }
    return animation
}
