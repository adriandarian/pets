import Foundation

public final class CuteCloudPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        let artPack = PetArtPack(
            idle: cuteCloudAnimation(state: "idle", duration: 1.1, motion: .breathe),
            busy: cuteCloudAnimation(state: "busy", duration: 0.72, motion: .bob),
            waiting: cuteCloudAnimation(state: "waiting", duration: 0.85, motion: .sway),
            excited: cuteCloudAnimation(state: "excited", duration: 0.55, motion: .pulse),
            sleeping: cuteCloudAnimation(state: "sleeping", duration: 1.4, motion: .breathe)
        )
        super.init(
            id: .cuteCloud,
            displayName: "Cute Cloud",
            category: .cloudPets,
            capabilities: PetCapabilities(
                maximumPixelation: .medium,
                supportsStatusMoods: true,
                supportsHoverExcitement: true
            ),
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

private func cuteCloudAnimation(
    state: String,
    duration: TimeInterval,
    motion: PetMotionPreset
) -> PetAnimation {
    guard let animation = PetAnimation(
        frames: [
            PetAnimationFrame(
                resourceName: "frame-000",
                resourceExtension: "png",
                subdirectory: "PetArt/cute-cloud/\(state)",
                duration: duration
            )
        ],
        loopBehavior: .loop,
        motion: motion
    ) else {
        preconditionFailure("Cute Cloud animation must contain a valid frame")
    }
    return animation
}
