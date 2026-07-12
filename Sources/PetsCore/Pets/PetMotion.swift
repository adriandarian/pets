import Foundation

public struct PetMotionSample: Equatable, Sendable {
    public let scale: Double
    public let xOffset: Double
    public let yOffset: Double
    public let rotationDegrees: Double
    public let shadowScale: Double
    public let shadowOpacityMultiplier: Double

    public init(
        scale: Double,
        xOffset: Double,
        yOffset: Double,
        rotationDegrees: Double,
        shadowScale: Double,
        shadowOpacityMultiplier: Double
    ) {
        self.scale = scale
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.rotationDegrees = rotationDegrees
        self.shadowScale = shadowScale
        self.shadowOpacityMultiplier = shadowOpacityMultiplier
    }

    public static let identity = PetMotionSample(
        scale: 1,
        xOffset: 0,
        yOffset: 0,
        rotationDegrees: 0,
        shadowScale: 1,
        shadowOpacityMultiplier: 1
    )
}

public extension PetMotionPreset {
    var cycleDuration: TimeInterval {
        switch self {
        case .none: 4.4
        case .breathe: 4.4
        case .bob: 4.8
        case .sway: 5.2
        case .pulse: 2.6
        }
    }

    func sample(at elapsed: TimeInterval, isEnabled: Bool) -> PetMotionSample {
        guard isEnabled, self != .none else { return .identity }

        let phase = sin(max(0, elapsed) * 2 * .pi / cycleDuration)
        let lift = (phase + 1) / 2

        switch self {
        case .none:
            return .identity
        case .breathe:
            return PetMotionSample(
                scale: 1 + phase * 0.022,
                xOffset: 0,
                yOffset: -3 * lift,
                rotationDegrees: 0,
                shadowScale: 1 - lift * 0.08,
                shadowOpacityMultiplier: 1 - lift * 0.18
            )
        case .bob:
            return PetMotionSample(
                scale: 1 + phase * 0.006,
                xOffset: 0,
                yOffset: 1 - lift * 5,
                rotationDegrees: 0,
                shadowScale: 1 - lift * 0.10,
                shadowOpacityMultiplier: 1 - lift * 0.22
            )
        case .sway:
            return PetMotionSample(
                scale: 1,
                xOffset: phase * 1.5,
                yOffset: -2 * lift,
                rotationDegrees: phase * 3,
                shadowScale: 1 - lift * 0.06,
                shadowOpacityMultiplier: 1 - lift * 0.14
            )
        case .pulse:
            return PetMotionSample(
                scale: 1 + phase * 0.04,
                xOffset: 0,
                yOffset: -lift,
                rotationDegrees: 0,
                shadowScale: 1 - lift * 0.04,
                shadowOpacityMultiplier: 1 - lift * 0.10
            )
        }
    }
}

public enum PetAnimationPhaseOffset {
    public static func normalized(for identifier: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in identifier.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }
}
