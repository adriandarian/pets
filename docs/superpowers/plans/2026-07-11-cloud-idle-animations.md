# Cloud Idle Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all five cloud pets visible species-specific idle life through eight-frame generated loops, smooth crossfades, ambient transforms, responsive shadows, and stable per-instance phase offsets.

**Architecture:** Extend `PetsCore` with deterministic frame-blend sampling and testable motion/phase samples, then make the existing asset renderer blend two transparent frames before applying one ambient transform and final pixelation. Integrate one species at a time by editing its canonical PNG into seven additional frames, validating resources/bounds, and reviewing a contact sheet before enabling the eight-frame manifest.

**Tech Stack:** Swift 6, SwiftUI, AppKit/ImageIO, Swift Testing, Swift Package Manager, OpenAI image generation/editing, macOS `sips`, macOS 14+

## Global Constraints

- Work on the existing `feature/pet-reaction-moods` branch and preserve all completed reaction behavior.
- Every cloud idle loop contains `frame-000.png` through `frame-007.png`, exactly eight 512x512 transparent PNGs.
- Reuse each existing `frame-000.png`; create 35 new frames by editing canonical images, never by unrelated regeneration.
- Use the `imagegen` skill and `image_gen` image-editing tool for semantic image changes. Local tools may only resize, encode, validate, or compose contact sheets.
- Preserve species identity, camera, voxel scale, materials, lighting direction, face placement, subject scale, and canvas anchor.
- Use the exact 5.56-second durations/blends from the design spec.
- Idle Motion off freezes `frame-000`, image transforms, and shadow movement.
- Completion/error reactions freeze idle keyframes and ambient transforms; reaction color/motion remains active.
- Use stable deterministic identifier hashing, never Swift `hashValue`, for phase offsets.
- Runtime image blending must preserve alpha; the shadow remains a separate sibling; pixelation remains outermost.
- Do not change persistence, session scanning, reaction detection/timing, settings UI, sounds, particles, or non-idle artwork.
- Reject identity-drifted or bounds-invalid generated frames and regenerate them; do not paint over them locally.
- Run the focused gate after each task and the full suite once before each commit.

---

## File Map

- Modify `Sources/PetsCore/Pets/PetAnimation.swift`: blend metadata, total duration, playback sample.
- Create `Sources/PetsCore/Pets/PetMotion.swift`: deterministic motion/shadow samples and stable phase derivation.
- Modify `Sources/PetsCore/Pets/PetVisualStateResolver.swift`: defaulted normalized phase value.
- Modify `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`: shared eight-frame manifest and per-species activation.
- Modify `Sources/Pets/PetSprites.swift`: blended image stack, sampled motion/shadow, reaction freeze.
- Modify `Sources/Pets/PetOverlayView.swift`: live per-instance phase offset.
- Create `scripts/build_idle_contact_sheet.swift`: deterministic 4x2 contact sheets.
- Create `Tests/PetsCoreTests/Pets/PetMotionTests.swift`: motion/phase behavior.
- Modify `Tests/PetsCoreTests/Pets/PetAnimationTests.swift`: blend validation and sampling.
- Modify `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`: exact manifests and alpha-bound tolerances.
- Modify `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`: renderer structure.
- Modify `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`: live phase wiring.
- Add 35 PNGs under `Sources/PetsCore/Resources/PetArt/*/idle/`.
- Add five contact sheets under `docs/assets/cloud-idle-loops/`.

---

### Task 1: Add Deterministic Frame Crossfade Sampling

**Files:**
- Modify: `Sources/PetsCore/Pets/PetAnimation.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetAnimationTests.swift`

**Interfaces:**
- Consumes: existing `PetAnimationFrame`, `PetAnimationLoopBehavior`, and `frameIndex(at:)` callers.
- Produces: `blendDuration`, `PetAnimationPlaybackSample`, `totalDuration`, and `playbackSample(at:)` while preserving `frameIndex(at:)`.

- [ ] **Step 1: Write failing validation and playback tests**

Add these tests to `PetAnimationTests`:

```swift
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
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter PetAnimationTests
```

Expected: compilation fails because `blendDuration`, `PetAnimationPlaybackSample`, `totalDuration`, and `playbackSample(at:)` do not exist.

- [ ] **Step 3: Implement blend metadata and sampling**

Add `blendDuration` with a backward-compatible default:

```swift
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
```

Replace `PetAnimation` validation and frame sampling with:

```swift
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
```

- [ ] **Step 4: Run GREEN and the full suite**

```bash
swift test --filter PetAnimationTests
swift test
```

Expected: focused tests and the full suite pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PetsCore/Pets/PetAnimation.swift Tests/PetsCoreTests/Pets/PetAnimationTests.swift
git commit -m "feat: add pet frame crossfades"
```

---

### Task 2: Add Testable Ambient Motion and Stable Phase Offsets

**Files:**
- Create: `Sources/PetsCore/Pets/PetMotion.swift`
- Create: `Tests/PetsCoreTests/Pets/PetMotionTests.swift`
- Modify: `Sources/PetsCore/Pets/PetVisualStateResolver.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift`

**Interfaces:**
- Consumes: `PetMotionPreset`, `PetVisualContext`, persisted instance identifier strings.
- Produces: `PetMotionSample`, `PetMotionPreset.sample(at:isEnabled:)`, `cycleDuration`, stable `PetAnimationPhaseOffset.normalized(for:)`, and defaulted `animationPhaseOffset` context.

- [ ] **Step 1: Write failing motion and phase tests**

Create `PetMotionTests.swift`:

```swift
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
```

Add a resolver/context compatibility test:

```swift
@Test
func visualContextDefaultsAnimationPhaseToZero() {
    let context = PetVisualContext(
        status: .idle,
        hasActiveSessions: true,
        isHovered: false,
        animationSettings: .default
    )

    #expect(context.animationPhaseOffset == 0)
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --filter PetMotionTests
swift test --filter PetVisualStateResolverTests
```

Expected: compilation fails on the missing motion/phase types and context property.

- [ ] **Step 3: Implement the motion engine**

Create `PetMotion.swift`:

```swift
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
```

Add the defaulted context field:

```swift
public let animationPhaseOffset: Double

public init(
    status: HarnessSessionStatus,
    hasActiveSessions: Bool,
    isHovered: Bool,
    animationSettings: PetAnimationSettings,
    reaction: PetReaction? = nil,
    animationPhaseOffset: Double = 0
) {
    self.status = status
    self.hasActiveSessions = hasActiveSessions
    self.isHovered = isHovered
    self.animationSettings = animationSettings
    self.reaction = reaction
    self.animationPhaseOffset = min(0.999_999, max(0, animationPhaseOffset))
}
```

- [ ] **Step 4: Run GREEN and the full suite**

```bash
swift test --filter PetMotionTests
swift test --filter PetVisualStateResolverTests
swift test
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PetsCore/Pets/PetMotion.swift Sources/PetsCore/Pets/PetVisualStateResolver.swift Tests/PetsCoreTests/Pets/PetMotionTests.swift Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift
git commit -m "feat: add ambient pet motion samples"
```

---

### Task 3: Blend Frames and Apply Ambient Motion in SwiftUI

**Files:**
- Modify: `Sources/Pets/PetSprites.swift`
- Modify: `Sources/Pets/PetOverlayView.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

**Interfaces:**
- Consumes: Tasks 1-2 playback/motion APIs and existing `PetReactionVisualModifier`.
- Produces: alpha-safe two-frame blending, sampled shadow/image motion, reaction freeze, live per-instance phase wiring.

- [ ] **Step 1: Write failing renderer/source integration tests**

Replace the obsolete `animation.frameIndex(at: elapsed)` assertion and add:

```swift
@Test
func petSpriteBlendsFramesBeforeOneAmbientTransform() throws {
    let source = try source("Sources/Pets/PetSprites.swift")

    #expect(source.contains("animation.playbackSample(at: playbackElapsed)"))
    #expect(source.contains("secondaryFrameIndex"))
    #expect(source.contains("secondaryOpacity"))
    #expect(source.contains("PetMotionSampleModifier("))
    #expect(source.contains("shadowScale"))
    #expect(source.contains("shadowOpacityMultiplier"))
    #expect(!source.contains("private struct PetMotionModifier"))
}

@Test
func reactionsFreezeIdlePlaybackAndAmbientMotion() throws {
    let source = try source("Sources/Pets/PetSprites.swift")

    #expect(source.contains("visualContext.reaction == nil"))
    #expect(source.contains("let playbackElapsed = isAmbientMotionEnabled ? phasedElapsed : 0"))
    #expect(source.contains("sample(at: phasedElapsed, isEnabled: isAmbientMotionEnabled)"))
}
```

Add to `PetOverlayTransparencyTests`:

```swift
@Test
func liveOverlayProvidesStablePerInstanceAnimationPhase() throws {
    let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(source.contains("animationPhaseOffset: PetAnimationPhaseOffset.normalized("))
    #expect(source.contains("for: petInstance.id.uuidString"))
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --filter PetSpriteSourceTests
swift test --filter PetOverlayTransparencyTests
```

Expected: new source assertions fail.

- [ ] **Step 3: Implement blended playback and sampled motion**

In `AssetPetSprite`, derive time and samples before the `GeometryReader`:

```swift
let rawElapsed = date.timeIntervalSinceReferenceDate
let phasedElapsed = rawElapsed
    + animation.totalDuration * visualContext.animationPhaseOffset
let isAmbientMotionEnabled = visualContext.animationSettings.isIdleMotionEnabled
    && visualContext.reaction == nil
let playbackElapsed = isAmbientMotionEnabled ? phasedElapsed : 0
let playback = animation.playbackSample(at: playbackElapsed)
let motionElapsed = rawElapsed
    + animation.motion.cycleDuration * visualContext.animationPhaseOffset
let motion = animation.motion.sample(
    at: motionElapsed,
    isEnabled: isAmbientMotionEnabled
)
```

Use `playback.primaryFrameIndex` and `playback.secondaryFrameIndex` to load images. Render them in one transparent stack:

```swift
@ViewBuilder
private func blendedPetImage(
    primary: NSImage,
    secondary: NSImage?,
    secondaryOpacity: Double
) -> some View {
    ZStack {
        petImage(primary)
        if let secondary {
            petImage(secondary)
                .opacity(secondaryOpacity)
        }
    }
}

private func petImage(_ image: NSImage) -> some View {
    Image(nsImage: image)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
}
```

Apply definition scale/anchor once to this stack, then:

```swift
.modifier(PetMotionSampleModifier(sample: motion))
.modifier(
    PetReactionVisualModifier(
        reaction: visualContext.reaction,
        elapsed: rawElapsed,
        isMotionEnabled: visualContext.animationSettings.isIdleMotionEnabled
    )
)
```

Replace `PetMotionModifier` with:

```swift
private struct PetMotionSampleModifier: ViewModifier {
    let sample: PetMotionSample

    func body(content: Content) -> some View {
        content
            .scaleEffect(sample.scale)
            .rotationEffect(.degrees(sample.rotationDegrees))
            .offset(x: sample.xOffset, y: sample.yOffset)
    }
}
```

Apply the same sample to the separate shadow:

```swift
.scaleEffect(x: motion.shadowScale, y: 1)
.opacity(motion.shadowOpacityMultiplier)
```

Keep `usesTimeline` true when idle motion is enabled and frames/motion/reactions require it. Keep `.pixelatedSpriteEffect(pixelation)` on the outer `PetSprite` group.

In the live overlay context add:

```swift
animationPhaseOffset: PetAnimationPhaseOffset.normalized(
    for: petInstance.id.uuidString
)
```

- [ ] **Step 4: Run focused GREEN and the full suite**

```bash
swift test --filter PetSpriteSourceTests
swift test --filter PetOverlayTransparencyTests
swift test --filter PetMotionTests
swift test --filter PetAnimationTests
swift test
```

Expected: all commands pass and the app target compiles.

- [ ] **Step 5: Commit**

```bash
git add Sources/Pets/PetSprites.swift Sources/Pets/PetOverlayView.swift Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift
git commit -m "feat: render ambient cloud animation"
```

---

### Task 4: Build the Shared Asset Pipeline and Cumulus Loop

**Files:**
- Create: `scripts/build_idle_contact_sheet.swift`
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/idle/frame-001.png` through `frame-007.png`
- Create: `docs/assets/cloud-idle-loops/cute-cloud.png`

**Interfaces:**
- Consumes: canonical `cute-cloud/idle/frame-000.png`, image-editing tool, existing resource locator.
- Produces: shared `cloudIdleAnimation(slug:motion:)`, generic alpha-bound validation, contact-sheet builder, complete Cumulus loop.

- [ ] **Step 1: Write failing Cumulus manifest and resource-bound tests**

Add a reusable exact-manifest assertion plus the Cumulus test:

```swift
@Test
func cumulusHasCompleteIdleLoop() throws {
    try assertCompleteIdleLoop(petID: .cuteCloud)
}

private func assertCompleteIdleLoop(petID: PetID) throws {
    let definition = try #require(PetCatalog.definition(for: petID))
    guard case let .assetPack(pack) = definition.renderSource else {
        Issue.record("Cumulus must use an asset pack")
        return
    }

    #expect(pack.idle.frames.map(\.resourceName) == (0..<8).map {
        String(format: "frame-%03d", $0)
    })
    #expect(pack.idle.frames.map(\.duration) == [2.00, 0.65, 0.55, 0.65, 1.45, 0.08, 0.10, 0.08])
    #expect(pack.idle.frames.map(\.blendDuration) == [0.22, 0.18, 0.20, 0.18, 0.12, 0.04, 0.04, 0.04])
}
```

Add a generic alpha-bounds check to `PetArtResourceTests`:

```swift
@Test
func idleFramesStayAnchoredToCanonicalBounds() throws {
    for definition in PetCatalog.definitions {
        guard case let .assetPack(pack) = definition.renderSource else { continue }
        let images = try pack.idle.frames.map { frame -> CGImage in
            let url = try #require(PetArtResourceLocator.url(for: frame))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        }
        let canonical = try #require(alphaBounds(in: images[0]))
        let sizeTolerance = definition.id == .cuteCloud || definition.id == .lenticularCloud
            ? 0.08
            : 0.12

        for image in images.dropFirst() {
            let bounds = try #require(alphaBounds(in: image))
            #expect(abs(bounds.midX - canonical.midX) <= 8)
            #expect(abs(bounds.midY - canonical.midY) <= 8)
            #expect(abs(bounds.width - canonical.width) / canonical.width <= sizeTolerance)
            #expect(abs(bounds.height - canonical.height) / canonical.height <= sizeTolerance)
        }
    }
}

private func alphaBounds(in image: CGImage) -> CGRect? {
    let bitmap = NSBitmapImageRep(cgImage: image)
    var minX = image.width
    var minY = image.height
    var maxX = -1
    var maxY = -1

    for y in 0..<image.height {
        for x in 0..<image.width where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}
```

- [ ] **Step 2: Run RED**

```bash
swift test --filter cumulusHasCompleteIdleLoop
```

Expected: the manifest-count assertion fails because Cumulus has one frame.

- [ ] **Step 3: Add the shared eight-frame manifest helper**

Add:

```swift
private let cloudIdleFrameTiming: [(duration: TimeInterval, blend: TimeInterval)] = [
    (2.00, 0.22),
    (0.65, 0.18),
    (0.55, 0.20),
    (0.65, 0.18),
    (1.45, 0.12),
    (0.08, 0.04),
    (0.10, 0.04),
    (0.08, 0.04),
]

private func cloudIdleAnimation(slug: String, motion: PetMotionPreset) -> PetAnimation {
    let frames = cloudIdleFrameTiming.enumerated().map { index, timing in
        PetAnimationFrame(
            resourceName: String(format: "frame-%03d", index),
            resourceExtension: "png",
            subdirectory: "PetArt/\(slug)/idle",
            duration: timing.duration,
            blendDuration: timing.blend
        )
    }
    guard let animation = PetAnimation(frames: frames, loopBehavior: .loop, motion: motion) else {
        preconditionFailure("Cloud idle animation must contain valid frames")
    }
    return animation
}
```

Switch only Cumulus idle to:

```swift
idle: cloudIdleAnimation(slug: "cute-cloud", motion: .breathe)
```

- [ ] **Step 4: Generate seven Cumulus edits with the image tool**

Read the `imagegen` skill. For each frame, call image editing with canonical reference:

```text
Sources/PetsCore/Resources/PetArt/cute-cloud/idle/frame-000.png
```

Use this invariant in every prompt:

```text
Edit the supplied canonical Cumulus voxel cloud into one subtle idle-animation keyframe. Preserve the exact character identity, three-quarter camera, voxel size, white material, warm studio lighting direction, black square eyes, blush, tiny mouth, arm construction, subject scale, and floor anchor. Keep a single isolated character on a fully transparent square canvas with no floor, cast shadow, border, text, glow, or background. Do not add or remove anatomy. Output one image only.
```

Append the exact frame instruction:

| Target | Frame instruction |
| --- | --- |
| `frame-001.png` | Early inhale: upper cloud expands about 2%, body rises slightly, hands begin lifting, eyes fully open, neutral tiny smile. |
| `frame-002.png` | Breathing peak: upper cloud softly rounded, body at highest pose, both hands lifted a few voxels, eyes bright and open, smile softened but still tiny. |
| `frame-003.png` | Exhale: volume and hands halfway back toward canonical, body settling, exact face identity retained. |
| `frame-004.png` | Secondary neutral: nearly canonical pose with only a tiny relaxed hand offset, eyes fully open. |
| `frame-005.png` | Half blink: canonical relaxed body, both eyes halfway closed with identical eye placement and width, mouth unchanged. |
| `frame-006.png` | Closed blink: canonical relaxed body, both eyes gently closed as short dark voxel lines, mouth and blush unchanged. |
| `frame-007.png` | Reopening: canonical relaxed body, both eyes halfway reopened, no other pose change. |

Use the accepted previous pose as an additional reference for frames `002`, `003`, `006`, and `007`, while keeping frame 000 as the primary identity reference.

Normalize each accepted square output mechanically by running `sips` on the exact local path returned by the image tool. For example, after the frame-001 tool result is saved as `output/imagegen/cumulus-frame-001.png`:

```bash
sips -z 512 512 output/imagegen/cumulus-frame-001.png --out Sources/PetsCore/Resources/PetArt/cute-cloud/idle/frame-001.png
```

- [ ] **Step 5: Create the contact-sheet builder and inspect Cumulus**

Create `scripts/build_idle_contact_sheet.swift`:

```swift
#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: build_idle_contact_sheet.swift INPUT_DIR OUTPUT_PNG\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let cell = NSSize(width: 256, height: 256)
let canvas = NSImage(size: NSSize(width: cell.width * 4, height: cell.height * 2))

canvas.lockFocus()
NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
NSRect(origin: .zero, size: canvas.size).fill()

for index in 0..<8 {
    let name = String(format: "frame-%03d.png", index)
    guard let image = NSImage(contentsOf: input.appending(path: name)) else {
        fputs("missing \(name)\n", stderr)
        exit(3)
    }
    let column = index % 4
    let row = 1 - index / 4
    image.draw(
        in: NSRect(
            x: CGFloat(column) * cell.width,
            y: CGFloat(row) * cell.height,
            width: cell.width,
            height: cell.height
        ),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else { exit(4) }
try png.write(to: output)
```

Run:

```bash
mkdir -p docs/assets/cloud-idle-loops
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/cute-cloud/idle docs/assets/cloud-idle-loops/cute-cloud.png
sips -g pixelWidth -g pixelHeight docs/assets/cloud-idle-loops/cute-cloud.png
```

Expected contact sheet size: 1024x512. Inspect it at original detail. Regenerate any frame with face/camera/voxel/anchor drift.

- [ ] **Step 6: Run GREEN and full suite**

```bash
swift test --filter cumulusHasCompleteIdleLoop
swift test --filter PetArtResourceTests
swift test
```

Expected: manifest, resource, bounds, and full tests pass.

- [ ] **Step 7: Commit**

```bash
git add scripts/build_idle_contact_sheet.swift Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Sources/PetsCore/Resources/PetArt/cute-cloud/idle docs/assets/cloud-idle-loops/cute-cloud.png
git commit -m "art: animate cumulus idle loop"
```

---

### Task 5: Generate and Integrate Nimbus

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create: `Sources/PetsCore/Resources/PetArt/nimbus-cloud/idle/frame-001.png` through `frame-007.png`
- Create: `docs/assets/cloud-idle-loops/nimbus-cloud.png`

**Interfaces:**
- Consumes: Task 4 pipeline and canonical Nimbus frame.
- Produces: complete eight-frame Nimbus idle loop using `.bob`.

- [ ] **Step 1: Add a failing Nimbus manifest test**

Add to `PetArtResourceTests`:

```swift
@Test
func nimbusHasCompleteIdleLoop() throws {
    try assertCompleteIdleLoop(petID: .nimbusCloud)
}
```

Run `swift test --filter nimbusHasCompleteIdleLoop`; expect frame-count failure.

- [ ] **Step 2: Generate Nimbus frames with image editing**

Use canonical `PetArt/nimbus-cloud/idle/frame-000.png` and this invariant:

```text
Edit the supplied canonical Nimbus voxel storm cloud into one subtle idle-animation keyframe. Preserve the exact character identity, three-quarter camera, voxel size, white upper cloud, charcoal lower cloud, blue raindrop count and attachment layout, single yellow lightning bolt, warm studio lighting direction, face, blush, arms, subject scale, and floor anchor. Keep a single isolated character on a fully transparent square canvas with no floor, cast shadow, border, text, aura, or background. Do not add or remove raindrops, lightning branches, or anatomy. Output one image only.
```

| Target | Frame instruction |
| --- | --- |
| `001` | Early weighted rise: body rises slightly; hanging raindrops trail one or two voxels downward; eyes open; lightning unchanged. |
| `002` | Hover peak: body at highest subtle pose; raindrops lag gently; lightning is only slightly brighter, never glowing outside its voxels. |
| `003` | Settling: body and drops halfway back; lightning returns to canonical brightness. |
| `004` | Heavy neutral hold: nearly canonical, with drops offset slightly opposite frame 001. |
| `005` | Slow half blink; canonical body, drops, lightning, mouth, and blush. |
| `006` | Closed determined blink as short dark voxel lines; every weather element unchanged. |
| `007` | Half reopened eyes; all other elements canonical. |

Use the canonical plus accepted neighboring frames (`001` for `002`, `002` for `003`, `004` for `005`, `005` for `006`, and `006` for `007`). Normalize every accepted result with `sips -z 512 512`, switch Nimbus to `cloudIdleAnimation(slug: "nimbus-cloud", motion: .bob)`, then build and inspect its contact sheet:

```bash
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/nimbus-cloud/idle docs/assets/cloud-idle-loops/nimbus-cloud.png
sips -g pixelWidth -g pixelHeight docs/assets/cloud-idle-loops/nimbus-cloud.png
```

Expected size: 1024x512. Regenerate any drifted frame.

- [ ] **Step 3: Run and commit**

```bash
swift test --filter nimbusHasCompleteIdleLoop
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Sources/PetsCore/Resources/PetArt/nimbus-cloud/idle docs/assets/cloud-idle-loops/nimbus-cloud.png
git commit -m "art: animate nimbus idle loop"
```

---

### Task 6: Generate and Integrate Cirrus

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create: `Sources/PetsCore/Resources/PetArt/cirrus-cloud/idle/frame-001.png` through `frame-007.png`
- Create: `docs/assets/cloud-idle-loops/cirrus-cloud.png`

**Interfaces:**
- Consumes: shared pipeline and canonical Cirrus.
- Produces: complete eight-frame Cirrus loop using `.sway`.

- [ ] **Step 1: Add the failing Cirrus manifest test**

```swift
@Test
func cirrusHasCompleteIdleLoop() throws {
    try assertCompleteIdleLoop(petID: .cirrusCloud)
}
```

Run `swift test --filter cirrusHasCompleteIdleLoop`; expect frame-count failure.

- [ ] **Step 2: Generate the Cirrus edits**

Invariant:

```text
Edit the supplied canonical Cirrus voxel wind cloud into one subtle idle-animation keyframe. Preserve the exact character identity, three-quarter camera, voxel size, pearly white material, warm lighting direction, face, blush, arms, body scale, and the exact count and attachment order of all long wind tendrils. Keep one isolated character on a fully transparent square canvas with no floor, cast shadow, border, text, or background. Tendrils may curl by only a few voxels and may not merge, split, disappear, or change count. Output one image only.
```

| Target | Frame instruction |
| --- | --- |
| `001` | Early breeze: body drifts slightly left; tendril tips curl a few voxels upward; both eyes open. |
| `002` | Breeze peak: body at leftmost subtle pose; tendril curves reach their approved maximum without changing count. |
| `003` | Relaxing toward canonical; tendrils halfway returned. |
| `004` | Secondary neutral with a tiny rightward drift and opposite tendril-tip relaxation. |
| `005` | Playful wink begins: viewer-right eye half closed; viewer-left eye open; body/tendrils near canonical. |
| `006` | Viewer-right eye fully winked as a short dark voxel line; other eye open; no other change. |
| `007` | Viewer-right eye halfway reopened; exact canonical face placement. |

Normalize every accepted result with `sips -z 512 512`, switch Cirrus to `cloudIdleAnimation(slug: "cirrus-cloud", motion: .sway)`, and build its sheet:

```bash
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/cirrus-cloud/idle docs/assets/cloud-idle-loops/cirrus-cloud.png
sips -g pixelWidth -g pixelHeight docs/assets/cloud-idle-loops/cirrus-cloud.png
```

Inspect at original detail, regenerate rejected frames, then run and commit:

```bash
swift test --filter cirrusHasCompleteIdleLoop
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Sources/PetsCore/Resources/PetArt/cirrus-cloud/idle docs/assets/cloud-idle-loops/cirrus-cloud.png
git commit -m "art: animate cirrus idle loop"
```

---

### Task 7: Generate and Integrate Lenticular

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create: `Sources/PetsCore/Resources/PetArt/lenticular-cloud/idle/frame-001.png` through `frame-007.png`
- Create: `docs/assets/cloud-idle-loops/lenticular-cloud.png`

**Interfaces:**
- Consumes: shared pipeline and canonical Lenticular.
- Produces: complete eight-frame Lenticular loop using `.breathe`.

- [ ] **Step 1: Add the failing Lenticular manifest test**

```swift
@Test
func lenticularHasCompleteIdleLoop() throws {
    try assertCompleteIdleLoop(petID: .lenticularCloud)
}
```

Run `swift test --filter lenticularHasCompleteIdleLoop`; expect frame-count failure.

- [ ] **Step 2: Generate the Lenticular edits**

Invariant:

```text
Edit the supplied canonical Lenticular voxel cloud into one subtle idle-animation keyframe. Preserve the exact character identity, three-quarter camera, voxel size, pearly material, warm lighting, face, blush, arms, subject scale, floor anchor, and the exact number and thickness of upper and lower concentric cloud bands. Keep one isolated character on a fully transparent square canvas with no floor, cast shadow, border, text, or background. Bands may shift laterally by only a few voxels and may not merge, split, or change count. Output one image only.
```

| Target | Frame instruction |
| --- | --- |
| `001` | Early hover: body rises slightly; upper band shifts one or two voxels viewer-left, lower band viewer-right; eyes open. |
| `002` | Controlled peak: maximum approved opposite band offsets; body highest; silhouette remains balanced. |
| `003` | Bands and body halfway returning to canonical. |
| `004` | Secondary neutral with extremely small opposite band offset; eyes open. |
| `005` | Calm half blink; bands and body canonical. |
| `006` | Calm closed blink as two short dark voxel lines; all bands unchanged. |
| `007` | Half reopened eyes; all other geometry canonical. |

Normalize every result, switch Lenticular to `cloudIdleAnimation(slug: "lenticular-cloud", motion: .breathe)`, build/inspect its sheet, then run:

```bash
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/lenticular-cloud/idle docs/assets/cloud-idle-loops/lenticular-cloud.png
sips -g pixelWidth -g pixelHeight docs/assets/cloud-idle-loops/lenticular-cloud.png
swift test --filter lenticularHasCompleteIdleLoop
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Sources/PetsCore/Resources/PetArt/lenticular-cloud/idle docs/assets/cloud-idle-loops/lenticular-cloud.png
git commit -m "art: animate lenticular idle loop"
```

---

### Task 8: Generate Snow Cloud and Enforce All 40 Frames

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create: `Sources/PetsCore/Resources/PetArt/snow-cloud/idle/frame-001.png` through `frame-007.png`
- Create: `docs/assets/cloud-idle-loops/snow-cloud.png`

**Interfaces:**
- Consumes: shared pipeline and canonical Snow Cloud.
- Produces: complete Snow loop and final all-cloud exact-manifest invariant.

- [ ] **Step 1: Add failing Snow and final all-cloud tests**

```swift
@Test
func everyCloudHasExactlyEightIdleFrames() throws {
    for definition in PetCatalog.definitions {
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Every cloud must use an asset pack")
            continue
        }
        #expect(pack.idle.frames.count == 8)
        #expect(pack.idle.frames.map(\.resourceName) == (0..<8).map {
            String(format: "frame-%03d", $0)
        })
    }
}
```

Run the focused test; expect failure only for Snow before integration.

- [ ] **Step 2: Generate Snow Cloud edits**

Invariant:

```text
Edit the supplied canonical Snow Cloud voxel character into one subtle idle-animation keyframe. Preserve the exact character identity, three-quarter camera, voxel size, white upper cloud, blue ice gradient, warm lighting direction, face, blush, arms, subject scale, floor anchor, and the exact count and attachment points of icicles and visible snowflakes. Keep one isolated character on a fully transparent square canvas with no floor, cast shadow, border, text, loose particles, or background. Snowflakes and icicles may shift by only a few voxels and may not appear, disappear, merge, or change count. Output one image only.
```

| Target | Frame instruction |
| --- | --- |
| `001` | Early buoyant rise: cloud lifts slightly; icicle tips trail by one or two voxels; snowflakes shift gently; eyes open. |
| `002` | Breathing peak: body highest; icicles at maximum subtle sway; snowflakes slightly brighter only within existing voxels. |
| `003` | Exhale: body, icicles, and snowflakes halfway back; brightness canonicalizing. |
| `004` | Cozy neutral hold with a tiny opposite icicle/snowflake offset; eyes open. |
| `005` | Cozy half blink; weather elements and body canonical. |
| `006` | Closed blink as two short dark voxel lines; smile, blush, icicles, and snowflakes unchanged. |
| `007` | Half reopened eyes; all other geometry canonical. |

Normalize every accepted result, switch Snow to `cloudIdleAnimation(slug: "snow-cloud", motion: .breathe)`, build/inspect its contact sheet, and regenerate drifted frames:

```bash
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/snow-cloud/idle docs/assets/cloud-idle-loops/snow-cloud.png
sips -g pixelWidth -g pixelHeight docs/assets/cloud-idle-loops/snow-cloud.png
```

- [ ] **Step 3: Run final asset gates and commit**

```bash
swift test --filter everyCloudHasExactlyEightIdleFrames
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Sources/PetsCore/Resources/PetArt/snow-cloud/idle docs/assets/cloud-idle-loops/snow-cloud.png
git commit -m "art: animate snow cloud idle loop"
```

---

### Task 9: Verify All Idle Loops in the Packaged App

**Files:**
- Verify: all Task 1-8 files
- Verify: `dist/Pets.app`
- Verify: five contact sheets

**Interfaces:**
- Consumes: completed engine, renderer, manifests, and 40 frames.
- Produces: fresh automated/build/bundle evidence and explicit visual acceptance or a scoped correction cycle.

- [ ] **Step 1: Inspect every contact sheet at original detail**

Open:

```text
docs/assets/cloud-idle-loops/cute-cloud.png
docs/assets/cloud-idle-loops/nimbus-cloud.png
docs/assets/cloud-idle-loops/cirrus-cloud.png
docs/assets/cloud-idle-loops/lenticular-cloud.png
docs/assets/cloud-idle-loops/snow-cloud.png
```

Check identity, face centroid, camera, voxel size, anchor, secondary-element counts, breathing continuity, and blink sequence. Any rejected frame returns to its species task for regeneration and re-review.

- [ ] **Step 2: Run focused gates**

```bash
swift test --filter PetAnimationTests
swift test --filter PetMotionTests
swift test --filter PetVisualStateResolverTests
swift test --filter PetArtResourceTests
swift test --filter PetSpriteSourceTests
swift test --filter PetOverlayTransparencyTests
```

Expected: every focused suite passes.

- [ ] **Step 3: Run full repository verification**

```bash
./scripts/check.sh
```

Expected: all Swift tests pass and the debug build succeeds.

- [ ] **Step 4: Rebuild and launch the packaged bundle**

```bash
./scripts/run_app.sh --verify
pgrep -x Pets
```

Expected: `Launched dist/Pets.app` and a live `Pets` process from this worktree bundle.

- [ ] **Step 5: Perform live visual checks**

Before changing the UI, record the exact selected species, pixelation, and Idle Motion values. For each species, select it through the normal UI and observe at least one full 5.56-second loop:

1. Movement remains visible but gentle at the overlay's 0.72 scale.
2. Frame blends do not flash, jump canvas, or create double edges.
3. Blink/wink is quick and readable.
4. Shadow contraction matches lift.
5. Transparent edges remain clean.
6. Turning Idle Motion off freezes frame 000, subject transform, and shadow; restore the setting afterward.
7. Triggering an available completion/error reaction freezes idle keyframes and ambient transform without disabling reaction movement.
8. Temporarily switch pixelation from its recorded original value to Medium, confirm the full blended/reaction-treated result remains coherent and rectangle-free, then restore the exact original value.
9. Restore the original selected species, pixelation, and Idle Motion values before completing verification.

If multiple pets already exist, verify they are out of phase. Do not create or persist extra pets solely for verification; phase behavior is covered by deterministic tests.

- [ ] **Step 6: Final branch checks**

```bash
git status --short
git diff --check
git log -12 --oneline
```

Expected: no unintended files, no whitespace errors, and all task commits present. If visual verification exposes a defect, add a failing focused test, make one scoped correction, rerun its focused suite and `./scripts/check.sh`, then commit with a descriptive `fix:` subject.
