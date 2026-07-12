import Testing
@testable import PetsCore

@Suite
struct PetAnimationTests {
    private let idleFrame = PetAnimationFrame(
        resourceName: "frame-000",
        resourceExtension: "png",
        subdirectory: "PetArt/test/idle",
        duration: 0.8
    )

    @Test
    func animationRequiresAtLeastOnePositiveDurationFrame() {
        #expect(PetAnimation(frames: [], loopBehavior: .loop, motion: .none) == nil)
        #expect(PetAnimation(
            frames: [PetAnimationFrame(
                resourceName: "bad",
                resourceExtension: "png",
                subdirectory: "PetArt/test/idle",
                duration: 0
            )],
            loopBehavior: .loop,
            motion: .none
        ) == nil)
        #expect(PetAnimation(frames: [idleFrame], loopBehavior: .loop, motion: .breathe) != nil)
    }

    @Test
    func missingOptionalStateResolvesDirectlyToIdle() throws {
        let idle = try #require(PetAnimation(
            frames: [idleFrame],
            loopBehavior: .loop,
            motion: .breathe
        ))
        let pack = PetArtPack(idle: idle)

        #expect(pack.animation(for: .waiting) == nil)
        #expect(pack.resolvedAnimation(for: .waiting) == idle)
        #expect(pack.resolvedAnimation(for: .excited) == idle)
        #expect(pack.resolvedAnimation(for: .sleeping) == idle)
        #expect(pack.animation(for: .completion) == nil)
        #expect(pack.animation(for: .error) == nil)
        #expect(pack.resolvedAnimation(for: .completion) == idle)
        #expect(pack.resolvedAnimation(for: .error) == idle)
    }

    @Test
    func frameIndexUsesConfiguredDurationsAndLooping() throws {
        let animation = try #require(PetAnimation(
            frames: [
                PetAnimationFrame(
                    resourceName: "0",
                    resourceExtension: "png",
                    subdirectory: "x",
                    duration: 0.25
                ),
                PetAnimationFrame(
                    resourceName: "1",
                    resourceExtension: "png",
                    subdirectory: "x",
                    duration: 0.75
                )
            ],
            loopBehavior: .loop,
            motion: .none
        ))

        #expect(animation.frameIndex(at: 0.10) == 0)
        #expect(animation.frameIndex(at: 0.50) == 1)
        #expect(animation.frameIndex(at: 1.10) == 0)
    }
}
