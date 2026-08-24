import Foundation

public final class LoafletPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .loaflet,
            displayName: "Loaflet",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.96,
                anchorX: 0,
                anchorY: 3,
                shadowWidth: 78,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "loaflet",
                    idleMotion: .breathe,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class InkpawPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .inkpaw,
            displayName: "Inkpaw",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 72,
                shadowHeight: 11,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "inkpaw",
                    idleMotion: .sway,
                    busyMotion: .sway,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class BramblekitPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .bramblekit,
            displayName: "Bramblekit",
            rarity: .rare,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 2,
                shadowWidth: 90,
                shadowHeight: 11,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "bramblekit",
                    idleMotion: .breathe,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class TuftmerePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .tuftmere,
            displayName: "Tuftmere",
            rarity: .rare,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.87,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 96,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "tuftmere",
                    idleMotion: .breathe,
                    busyMotion: .breathe,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class NovaPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .nova,
            displayName: "Nova",
            rarity: .legendary,
            category: .whiskerkin,
            capabilities: .whiskerkin,
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
                whiskerkinArtPack(
                    slug: "nova",
                    idleMotion: .sway,
                    busyMotion: .sway,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class MarmaladePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .marmalade,
            displayName: "Marmalade",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.91,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 84,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "marmalade",
                    idleMotion: .breathe,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class MittensPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .mittens,
            displayName: "Mittens",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.89,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 74,
                shadowHeight: 11,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "mittens",
                    idleMotion: .sway,
                    busyMotion: .bob,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class PebblePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .pebble,
            displayName: "Pebble",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.96,
                anchorX: 0,
                anchorY: 3,
                shadowWidth: 88,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "pebble",
                    idleMotion: .breathe,
                    busyMotion: .bob,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class CalypsoPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .calypso,
            displayName: "Calypso",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.92,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 80,
                shadowHeight: 11,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "calypso",
                    idleMotion: .bob,
                    busyMotion: .bob,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class SootPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .soot,
            displayName: "Soot",
            rarity: .common,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.90,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 76,
                shadowHeight: 11,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "soot",
                    idleMotion: .sway,
                    busyMotion: .sway,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class MallowPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .mallow,
            displayName: "Mallow",
            rarity: .rare,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.87,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 96,
                shadowHeight: 12,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "mallow",
                    idleMotion: .breathe,
                    busyMotion: .breathe,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class VelvetPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .velvet,
            displayName: "Velvet",
            rarity: .rare,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.91,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 70,
                shadowHeight: 10,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "velvet",
                    idleMotion: .sway,
                    busyMotion: .bob,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class BluebellPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .bluebell,
            displayName: "Bluebell",
            rarity: .rare,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 94,
                shadowHeight: 12,
                shadowOpacity: 0.15,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "bluebell",
                    idleMotion: .breathe,
                    busyMotion: .sway,
                    waitingMotion: .sway
                )
            )
        )
    }
}

public final class AurumPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .aurum,
            displayName: "Aurum",
            rarity: .legendary,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.88,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 82,
                shadowHeight: 11,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "aurum",
                    idleMotion: .sway,
                    busyMotion: .sway,
                    waitingMotion: .breathe
                )
            )
        )
    }
}

public final class MiragePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .mirage,
            displayName: "Mirage",
            rarity: .legendary,
            category: .whiskerkin,
            capabilities: .whiskerkin,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.84,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 98,
                shadowHeight: 11,
                shadowOpacity: 0.13,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(
                whiskerkinArtPack(
                    slug: "mirage",
                    idleMotion: .sway,
                    busyMotion: .sway,
                    waitingMotion: .sway
                )
            )
        )
    }
}

private extension PetCapabilities {
    static let whiskerkin = PetCapabilities(
        maximumPixelation: .medium,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func whiskerkinArtPack(
    slug: String,
    idleMotion: PetMotionPreset,
    busyMotion: PetMotionPreset,
    waitingMotion: PetMotionPreset
) -> PetArtPack {
    PetArtPack(
        idle: whiskerkinAnimation(
            slug: slug,
            state: "idle",
            durations: [1.65, 0.52, 0.48, 0.52, 1.25, 0.13, 0.13, 0.13],
            blends: [0.18, 0.16, 0.16, 0.16, 0.12, 0.04, 0.04, 0.04],
            motion: idleMotion
        ),
        busy: whiskerkinAnimation(
            slug: slug,
            state: "busy",
            durations: [0.24, 0.22, 0.22, 0.24],
            blends: [0.08, 0.08, 0.08, 0.08],
            motion: busyMotion
        ),
        waiting: whiskerkinAnimation(
            slug: slug,
            state: "waiting",
            durations: [0.72, 0.54, 0.54, 0.72],
            blends: [0.16, 0.16, 0.16, 0.16],
            motion: waitingMotion
        ),
        excited: whiskerkinAnimation(
            slug: slug,
            state: "excited",
            durations: [0.18, 0.16, 0.16, 0.18, 0.28],
            blends: [0.06, 0.06, 0.06, 0.06, 0.08],
            motion: .pulse
        ),
        sleeping: whiskerkinAnimation(
            slug: slug,
            state: "sleeping",
            durations: [1.35, 0.76, 0.76, 1.35],
            blends: [0.18, 0.18, 0.18, 0.18],
            motion: .breathe
        )
    )
}

private func whiskerkinAnimation(
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
        preconditionFailure("Whiskerkin animation configuration must be valid")
    }
    return animation
}
