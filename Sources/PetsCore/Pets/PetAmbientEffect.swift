import Foundation

public enum PetAmbientEffectKind: Equatable, Sendable {
    case none
    case storm
    case wind
    case snow

    public func sample(
        at elapsed: TimeInterval,
        phaseOffset: Double,
        isEnabled: Bool
    ) -> PetAmbientEffectSample {
        switch self {
        case .none:
            return .none
        case .storm:
            return stormSample(at: elapsed, phaseOffset: phaseOffset, isEnabled: isEnabled)
        case .wind:
            return windSample(at: elapsed, phaseOffset: phaseOffset, isEnabled: isEnabled)
        case .snow:
            return snowSample(at: elapsed, phaseOffset: phaseOffset, isEnabled: isEnabled)
        }
    }
}

public struct PetAmbientParticleSample: Equatable, Identifiable, Sendable {
    public let id: Int
    public let x: Double
    public let y: Double
    public let opacity: Double
    public let scale: Double
    public let stretch: Double
    public let rotationDegrees: Double

    public init(
        id: Int,
        x: Double,
        y: Double,
        opacity: Double,
        scale: Double,
        stretch: Double,
        rotationDegrees: Double
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.opacity = opacity
        self.scale = scale
        self.stretch = stretch
        self.rotationDegrees = rotationDegrees
    }
}

public struct PetAmbientEffectSample: Equatable, Sendable {
    public let particles: [PetAmbientParticleSample]
    public let lightningIntensity: Double

    public init(
        particles: [PetAmbientParticleSample],
        lightningIntensity: Double
    ) {
        self.particles = particles
        self.lightningIntensity = lightningIntensity
    }

    public static let none = PetAmbientEffectSample(
        particles: [],
        lightningIntensity: 0
    )
}

private struct AmbientSeed: Sendable {
    let x: Double
    let y: Double
    let phase: Double
    let speed: Double
    let scale: Double
    let stretch: Double
    let drift: Double
}

private let snowSeeds = [
    AmbientSeed(x: -34, y: 0, phase: 0.04, speed: 1.00, scale: 0.72, stretch: 1, drift: 3.4),
    AmbientSeed(x: -20, y: 0, phase: 0.52, speed: 0.86, scale: 0.92, stretch: 1, drift: 4.2),
    AmbientSeed(x: -7, y: 0, phase: 0.24, speed: 1.08, scale: 0.64, stretch: 1, drift: 2.8),
    AmbientSeed(x: 8, y: 0, phase: 0.76, speed: 0.92, scale: 0.82, stretch: 1, drift: 3.8),
    AmbientSeed(x: 22, y: 0, phase: 0.35, speed: 1.14, scale: 0.68, stretch: 1, drift: 3.0),
    AmbientSeed(x: 35, y: 0, phase: 0.88, speed: 0.80, scale: 0.88, stretch: 1, drift: 4.5),
]

private let rainSeeds = [
    AmbientSeed(x: -31, y: 0, phase: 0.05, speed: 1.00, scale: 0.86, stretch: 1, drift: 0),
    AmbientSeed(x: -21, y: 0, phase: 0.44, speed: 1.14, scale: 0.72, stretch: 1, drift: 0),
    AmbientSeed(x: -11, y: 0, phase: 0.72, speed: 0.92, scale: 1.00, stretch: 1, drift: 0),
    AmbientSeed(x: 0, y: 0, phase: 0.26, speed: 1.08, scale: 0.78, stretch: 1, drift: 0),
    AmbientSeed(x: 11, y: 0, phase: 0.60, speed: 0.96, scale: 0.92, stretch: 1, drift: 0),
    AmbientSeed(x: 21, y: 0, phase: 0.12, speed: 1.18, scale: 0.70, stretch: 1, drift: 0),
    AmbientSeed(x: 31, y: 0, phase: 0.84, speed: 1.04, scale: 0.84, stretch: 1, drift: 0),
]

private let windSeeds = [
    AmbientSeed(x: 0, y: -22, phase: 0.02, speed: 1.00, scale: 0.72, stretch: 1.10, drift: 2.0),
    AmbientSeed(x: 0, y: -8, phase: 0.31, speed: 0.82, scale: 0.88, stretch: 1.45, drift: 1.4),
    AmbientSeed(x: 0, y: 9, phase: 0.58, speed: 1.16, scale: 0.66, stretch: 0.92, drift: 2.4),
    AmbientSeed(x: 0, y: 23, phase: 0.79, speed: 0.93, scale: 0.78, stretch: 1.28, drift: 1.8),
]

private extension PetAmbientEffectKind {
    func snowSample(
        at elapsed: TimeInterval,
        phaseOffset: Double,
        isEnabled: Bool
    ) -> PetAmbientEffectSample {
        let cycleDuration = 3.8
        let time = effectiveElapsed(
            elapsed,
            phaseOffset: phaseOffset,
            cycleDuration: cycleDuration,
            isEnabled: isEnabled
        )
        let particles = snowSeeds.enumerated().map { index, seed in
            let progress = unitPhase(time / cycleDuration * seed.speed + seed.phase)
            let shimmer = (sin(progress * 2 * .pi + seed.phase * .pi) + 1) / 2
            return PetAmbientParticleSample(
                id: index,
                x: seed.x + sin(progress * 2 * .pi + seed.phase * 4) * seed.drift,
                y: 4 + progress * 48,
                opacity: 0.68 + shimmer * 0.26,
                scale: seed.scale,
                stretch: seed.stretch,
                rotationDegrees: progress * 220 + seed.phase * 90
            )
        }
        return PetAmbientEffectSample(particles: particles, lightningIntensity: 0)
    }

    func stormSample(
        at elapsed: TimeInterval,
        phaseOffset: Double,
        isEnabled: Bool
    ) -> PetAmbientEffectSample {
        let rainCycleDuration = 1.25
        let time = effectiveElapsed(
            elapsed,
            phaseOffset: phaseOffset,
            cycleDuration: rainCycleDuration,
            isEnabled: isEnabled
        )
        let particles = rainSeeds.enumerated().map { index, seed in
            let progress = unitPhase(time / rainCycleDuration * seed.speed + seed.phase)
            return PetAmbientParticleSample(
                id: index,
                x: seed.x,
                y: 7 + progress * 41,
                opacity: 0.66 + seed.scale * 0.26,
                scale: seed.scale,
                stretch: 0.86 + seed.scale * 0.34,
                rotationDegrees: 7
            )
        }

        guard isEnabled else {
            return PetAmbientEffectSample(particles: particles, lightningIntensity: 0)
        }

        let lightningTime = max(0, elapsed) + unitPhase(phaseOffset) * 4.8
        let lightningPhase = unitPhase(lightningTime / 4.8 + 0.55)
        let firstPulse = triangularPulse(at: lightningPhase, center: 0.16, halfWidth: 0.035)
        let secondPulse = triangularPulse(at: lightningPhase, center: 0.24, halfWidth: 0.025) * 0.72
        return PetAmbientEffectSample(
            particles: particles,
            lightningIntensity: max(firstPulse, secondPulse)
        )
    }

    func windSample(
        at elapsed: TimeInterval,
        phaseOffset: Double,
        isEnabled: Bool
    ) -> PetAmbientEffectSample {
        let cycleDuration = 4.2
        let time = effectiveElapsed(
            elapsed,
            phaseOffset: phaseOffset,
            cycleDuration: cycleDuration,
            isEnabled: isEnabled
        )
        let particles = windSeeds.enumerated().map { index, seed in
            let progress = unitPhase(time / cycleDuration * seed.speed + seed.phase)
            let edgeFade = min(1, progress / 0.12, (1 - progress) / 0.12)
            return PetAmbientParticleSample(
                id: index,
                x: -58 + progress * 116,
                y: seed.y + sin(progress * 2 * .pi + seed.phase * 5) * seed.drift,
                opacity: max(0, edgeFade) * (0.72 + seed.scale * 0.18),
                scale: seed.scale,
                stretch: seed.stretch,
                rotationDegrees: 0
            )
        }
        return PetAmbientEffectSample(particles: particles, lightningIntensity: 0)
    }
}

private func effectiveElapsed(
    _ elapsed: TimeInterval,
    phaseOffset: Double,
    cycleDuration: TimeInterval,
    isEnabled: Bool
) -> TimeInterval {
    guard isEnabled else { return 0 }
    return max(0, elapsed) + unitPhase(phaseOffset) * cycleDuration
}

private func unitPhase(_ value: Double) -> Double {
    value - floor(value)
}

private func triangularPulse(
    at phase: Double,
    center: Double,
    halfWidth: Double
) -> Double {
    let rawDistance = abs(phase - center)
    let distance = min(rawDistance, 1 - rawDistance)
    return max(0, 1 - distance / halfWidth)
}
