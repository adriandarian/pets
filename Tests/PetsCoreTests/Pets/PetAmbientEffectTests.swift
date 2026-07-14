import Testing
@testable import PetsCore

@Suite
struct PetAmbientEffectTests {
    @Test
    func snowFallsAndWrapsToItsLaneStart() {
        let start = PetAmbientEffectKind.snow.sample(at: 0, phaseOffset: 0, isEnabled: true)
        let falling = PetAmbientEffectKind.snow.sample(at: 0.8, phaseOffset: 0, isEnabled: true)
        let wrapped = PetAmbientEffectKind.snow.sample(at: 3.8, phaseOffset: 0, isEnabled: true)

        #expect(falling.particles[0].y > start.particles[0].y)
        #expect(wrapped.particles[0].y < falling.particles[0].y)
    }

    @Test
    func stormRainFallsInStaggeredLanesAndLightningPulses() {
        let start = PetAmbientEffectKind.storm.sample(at: 0, phaseOffset: 0, isEnabled: true)
        let falling = PetAmbientEffectKind.storm.sample(at: 0.4, phaseOffset: 0, isEnabled: true)
        let pulse = PetAmbientEffectKind.storm.sample(at: 2.928, phaseOffset: 0, isEnabled: true)

        #expect(start.particles.count == 7)
        #expect(Set(start.particles.map(\.x)).count == 7)
        #expect(falling.particles[0].y > start.particles[0].y)
        #expect(start.lightningIntensity == 0)
        #expect(pulse.lightningIntensity > 0.95)
    }

    @Test
    func windTravelsRightAndFadesAtWrapEdges() {
        let edge = PetAmbientEffectKind.wind.sample(at: 0, phaseOffset: 0, isEnabled: true)
        let traveling = PetAmbientEffectKind.wind.sample(at: 0.6, phaseOffset: 0, isEnabled: true)
        let middle = PetAmbientEffectKind.wind.sample(at: 2.0, phaseOffset: 0, isEnabled: true)

        #expect(traveling.particles[0].x > edge.particles[0].x)
        #expect(edge.particles[0].opacity < middle.particles[0].opacity)
    }

    @Test
    func samplingIsDeterministicAndDisabledMotionFreezes() {
        let first = PetAmbientEffectKind.snow.sample(at: 1.25, phaseOffset: 0.37, isEnabled: true)
        let repeated = PetAmbientEffectKind.snow.sample(at: 1.25, phaseOffset: 0.37, isEnabled: true)
        let frozenEarly = PetAmbientEffectKind.snow.sample(at: 1, phaseOffset: 0.37, isEnabled: false)
        let frozenLate = PetAmbientEffectKind.snow.sample(at: 99, phaseOffset: 0.37, isEnabled: false)

        #expect(first == repeated)
        #expect(frozenEarly == frozenLate)
        #expect(PetAmbientEffectKind.none.sample(at: 4, phaseOffset: 0.2, isEnabled: true) == .none)
    }
}
