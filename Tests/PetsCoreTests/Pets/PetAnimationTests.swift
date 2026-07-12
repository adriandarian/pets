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

    @Test
    func animationRejectsInvalidBlendDurations() {
        let negativeBlend = PetAnimationFrame(
            resourceName: "negative",
            resourceExtension: "png",
            subdirectory: "x",
            duration: 1,
            blendDuration: -0.1
        )
        let excessiveBlend = PetAnimationFrame(
            resourceName: "excessive",
            resourceExtension: "png",
            subdirectory: "x",
            duration: 0.2,
            blendDuration: 0.3
        )

        #expect(PetAnimation(frames: [negativeBlend], loopBehavior: .loop, motion: .none) == nil)
        #expect(PetAnimation(frames: [excessiveBlend], loopBehavior: .loop, motion: .none) == nil)
    }

    @Test
    func playbackSampleHoldsThenBlendsToNextFrame() throws {
        let animation = try #require(twoFrameAnimation(loopBehavior: .loop))

        #expect(animation.totalDuration == 2)
        #expect(animation.playbackSample(at: 0.50) == PetAnimationPlaybackSample(
            primaryFrameIndex: 0,
            secondaryFrameIndex: nil,
            secondaryOpacity: 0
        ))

        let blend = animation.playbackSample(at: 0.875)
        #expect(blend.primaryFrameIndex == 0)
        #expect(blend.secondaryFrameIndex == 1)
        #expect(abs(blend.secondaryOpacity - 0.5) < 0.000_001)
    }

    @Test
    func loopingSampleBlendsLastFrameToFirst() throws {
        let animation = try #require(twoFrameAnimation(loopBehavior: .loop))
        let sample = animation.playbackSample(at: 1.875)

        #expect(sample.primaryFrameIndex == 1)
        #expect(sample.secondaryFrameIndex == 0)
        #expect(abs(sample.secondaryOpacity - 0.5) < 0.000_001)
    }

    @Test
    func oneShotSampleHoldsFinalFrame() throws {
        let animation = try #require(twoFrameAnimation(loopBehavior: .once))
        let sample = animation.playbackSample(at: 20)

        #expect(sample == PetAnimationPlaybackSample(
            primaryFrameIndex: 1,
            secondaryFrameIndex: nil,
            secondaryOpacity: 0
        ))
    }

    private func twoFrameAnimation(loopBehavior: PetAnimationLoopBehavior) -> PetAnimation? {
        PetAnimation(
            frames: [
                PetAnimationFrame(
                    resourceName: "0",
                    resourceExtension: "png",
                    subdirectory: "x",
                    duration: 1,
                    blendDuration: 0.25
                ),
                PetAnimationFrame(
                    resourceName: "1",
                    resourceExtension: "png",
                    subdirectory: "x",
                    duration: 1,
                    blendDuration: 0.25
                ),
            ],
            loopBehavior: loopBehavior,
            motion: .none
        )
    }
}
