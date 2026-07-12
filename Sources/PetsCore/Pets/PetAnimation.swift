import Foundation

public enum PetVisualState: String, CaseIterable, Sendable {
    case idle
    case busy
    case waiting
    case excited
    case sleeping
    case completion
    case error
}

public enum PetMotionPreset: Equatable, Sendable {
    case none
    case breathe
    case bob
    case sway
    case pulse
}

public enum PetAnimationLoopBehavior: Equatable, Sendable {
    case loop
    case once
}

public struct PetAnimationFrame: Equatable, Sendable {
    public let resourceName: String
    public let resourceExtension: String
    public let subdirectory: String
    public let duration: TimeInterval

    public init(
        resourceName: String,
        resourceExtension: String,
        subdirectory: String,
        duration: TimeInterval
    ) {
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
        self.subdirectory = subdirectory
        self.duration = duration
    }
}

public struct PetAnimation: Equatable, Sendable {
    public let frames: [PetAnimationFrame]
    public let loopBehavior: PetAnimationLoopBehavior
    public let motion: PetMotionPreset

    public init?(
        frames: [PetAnimationFrame],
        loopBehavior: PetAnimationLoopBehavior,
        motion: PetMotionPreset
    ) {
        guard !frames.isEmpty, frames.allSatisfy({ $0.duration > 0 }) else { return nil }
        self.frames = frames
        self.loopBehavior = loopBehavior
        self.motion = motion
    }

    public func frameIndex(at elapsed: TimeInterval) -> Int {
        guard frames.count > 1 else { return 0 }

        let totalDuration = frames.reduce(0) { $0 + $1.duration }
        let nonnegativeElapsed = max(0, elapsed)
        let position: TimeInterval
        switch loopBehavior {
        case .loop:
            position = nonnegativeElapsed.truncatingRemainder(dividingBy: totalDuration)
        case .once:
            if nonnegativeElapsed >= totalDuration {
                return frames.index(before: frames.endIndex)
            }
            position = nonnegativeElapsed
        }

        var boundary: TimeInterval = 0
        for (index, frame) in frames.enumerated() {
            boundary += frame.duration
            if position < boundary {
                return index
            }
        }
        return frames.index(before: frames.endIndex)
    }
}

public struct PetArtPack: Equatable, Sendable {
    public let idle: PetAnimation
    public let busy: PetAnimation?
    public let waiting: PetAnimation?
    public let excited: PetAnimation?
    public let sleeping: PetAnimation?
    public let completion: PetAnimation?
    public let error: PetAnimation?

    public init(
        idle: PetAnimation,
        busy: PetAnimation? = nil,
        waiting: PetAnimation? = nil,
        excited: PetAnimation? = nil,
        sleeping: PetAnimation? = nil,
        completion: PetAnimation? = nil,
        error: PetAnimation? = nil
    ) {
        self.idle = idle
        self.busy = busy
        self.waiting = waiting
        self.excited = excited
        self.sleeping = sleeping
        self.completion = completion
        self.error = error
    }

    public func animation(for state: PetVisualState) -> PetAnimation? {
        switch state {
        case .idle:
            idle
        case .busy:
            busy
        case .waiting:
            waiting
        case .excited:
            excited
        case .sleeping:
            sleeping
        case .completion:
            completion
        case .error:
            error
        }
    }

    public func resolvedAnimation(for state: PetVisualState) -> PetAnimation {
        animation(for: state) ?? idle
    }
}
