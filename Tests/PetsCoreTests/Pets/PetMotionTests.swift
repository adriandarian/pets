import Testing
@testable import PetsCore

@Suite
struct PetMotionTests {
    @Test
    func breathePeakIsVisibleAndLiftsItsShadow() {
        let sample = PetMotionPreset.breathe.sample(at: 1.1, isEnabled: true)

        #expect(abs(sample.scale - 1.022) < 0.000_001)
        #expect(abs(sample.yOffset + 3) < 0.000_001)
        #expect(abs(sample.shadowScale - 0.92) < 0.000_001)
        #expect(abs(sample.shadowOpacityMultiplier - 0.82) < 0.000_001)
    }

    @Test
    func bobAndSwayRetainSpeciesSpecificMovement() {
        let bob = PetMotionPreset.bob.sample(at: 1.2, isEnabled: true)
        let sway = PetMotionPreset.sway.sample(at: 1.3, isEnabled: true)

        #expect(abs(bob.yOffset + 4) < 0.000_001)
        #expect(abs(bob.shadowScale - 0.90) < 0.000_001)
        #expect(abs(sway.xOffset - 1.5) < 0.000_001)
        #expect(abs(sway.rotationDegrees - 3) < 0.000_001)
    }

    @Test
    func disabledAndNoneMotionReturnIdentity() {
        #expect(PetMotionPreset.breathe.sample(at: 1.1, isEnabled: false) == .identity)
        #expect(PetMotionPreset.none.sample(at: 1.1, isEnabled: true) == .identity)
    }

    @Test
    func phaseOffsetsAreStableDistinctAndNormalized() {
        let first = PetAnimationPhaseOffset.normalized(for: "E3BABD41-F4CC-47FB-92B4-A7A3E42AE0DF")
        let repeated = PetAnimationPhaseOffset.normalized(for: "E3BABD41-F4CC-47FB-92B4-A7A3E42AE0DF")
        let second = PetAnimationPhaseOffset.normalized(for: "11111111-2222-3333-4444-555555555555")

        #expect(first == repeated)
        #expect(first >= 0 && first < 1)
        #expect(second >= 0 && second < 1)
        #expect(first != second)
    }
}
