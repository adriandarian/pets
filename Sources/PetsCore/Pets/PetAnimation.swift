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
    public let blendDuration: TimeInterval

    public init(
        resourceName: String,
        resourceExtension: String,
        subdirectory: String,
        duration: TimeInterval,
        blendDuration: TimeInterval = 0
    ) {
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
        self.subdirectory = subdirectory
        self.duration = duration
        self.blendDuration = blendDuration
    }
}

public struct PetAnimationPlaybackSample: Equatable, Sendable {
    public let primaryFrameIndex: Int
    public let secondaryFrameIndex: Int?
    public let secondaryOpacity: Double

    public init(
        primaryFrameIndex: Int,
        secondaryFrameIndex: Int?,
        secondaryOpacity: Double
    ) {
        self.primaryFrameIndex = primaryFrameIndex
        self.secondaryFrameIndex = secondaryFrameIndex
        self.secondaryOpacity = secondaryOpacity
    }
}

public struct PetAnimation: Equatable, Sendable {
    public let frames: [PetAnimationFrame]
    public let loopBehavior: PetAnimationLoopBehavior
    public let motion: PetMotionPreset

    public var totalDuration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    public init?(
        frames: [PetAnimationFrame],
        loopBehavior: PetAnimationLoopBehavior,
        motion: PetMotionPreset
    ) {
        guard !frames.isEmpty,
              frames.allSatisfy({
                  $0.duration > 0
                      && $0.blendDuration >= 0
                      && $0.blendDuration <= $0.duration
              })
        else { return nil }
        self.frames = frames
        self.loopBehavior = loopBehavior
        self.motion = motion
    }

    public func frameIndex(at elapsed: TimeInterval) -> Int {
        playbackSample(at: elapsed).primaryFrameIndex
    }

    public func playbackSample(at elapsed: TimeInterval) -> PetAnimationPlaybackSample {
        guard frames.count > 1 else {
            return PetAnimationPlaybackSample(
                primaryFrameIndex: 0,
                secondaryFrameIndex: nil,
                secondaryOpacity: 0
            )
        }

        let nonnegativeElapsed = max(0, elapsed)
        if loopBehavior == .once, nonnegativeElapsed >= totalDuration {
            return PetAnimationPlaybackSample(
                primaryFrameIndex: frames.index(before: frames.endIndex),
                secondaryFrameIndex: nil,
                secondaryOpacity: 0
            )
        }

        let position = loopBehavior == .loop
            ? nonnegativeElapsed.truncatingRemainder(dividingBy: totalDuration)
            : nonnegativeElapsed

        var frameStart: TimeInterval = 0
        for (index, frame) in frames.enumerated() {
            let frameEnd = frameStart + frame.duration
            if position < frameEnd {
                let timeInFrame = position - frameStart
                let blendStart = frame.duration - frame.blendDuration
                guard frame.blendDuration > 0, timeInFrame >= blendStart else {
                    return PetAnimationPlaybackSample(
                        primaryFrameIndex: index,
                        secondaryFrameIndex: nil,
                        secondaryOpacity: 0
                    )
                }

                let nextIndex: Int?
                if index < frames.index(before: frames.endIndex) {
                    nextIndex = frames.index(after: index)
                } else {
                    nextIndex = loopBehavior == .loop ? 0 : nil
                }
                guard let nextIndex else {
                    return PetAnimationPlaybackSample(
                        primaryFrameIndex: index,
                        secondaryFrameIndex: nil,
                        secondaryOpacity: 0
                    )
                }

                let opacity = min(1, max(0, (timeInFrame - blendStart) / frame.blendDuration))
                return PetAnimationPlaybackSample(
                    primaryFrameIndex: index,
                    secondaryFrameIndex: nextIndex,
                    secondaryOpacity: opacity
                )
            }
            frameStart = frameEnd
        }

        return PetAnimationPlaybackSample(
            primaryFrameIndex: frames.index(before: frames.endIndex),
            secondaryFrameIndex: nil,
            secondaryOpacity: 0
        )
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
