# Cloud Ambient Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independently moving snow, rain/lightning, and horizontal wind to the Snow Cloud, Nimbus, and Cirrus pets.

**Architecture:** Add a pure deterministic ambient-effect sampler to `PetsCore`, store effect selection on `PetDefinition`, and render the samples as small SwiftUI voxel shapes around the existing blended pet image. The same timeline, stable instance phase, reaction freeze, and Idle Motion setting drive body and ambient motion.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, Swift Package Manager, macOS 14+

## Global Constraints

- Preserve every existing generated pet PNG unchanged.
- Keep **Idle Motion** as the only user-facing control for body and ambient animation.
- Freeze ambient animation during completion and error reactions, matching body-frame playback.
- Apply whole-pet motion and final pixelation after composing body and ambient layers.
- Use deterministic fixed-size sampling with no timers, random number generator, or new dependency.
- Preserve unrelated working-tree edits in `PetSettingsViews.swift` and `PetOverlayTransparencyTests.swift`.

---

### Task 1: Deterministic Ambient Motion Model and Definition Metadata

**Files:**
- Create: `Sources/PetsCore/Pets/PetAmbientEffect.swift`
- Create: `Tests/PetsCoreTests/Pets/PetAmbientEffectTests.swift`
- Modify: `Sources/PetsCore/Pets/PetDefinition.swift`
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetDefinitionTests.swift`

**Interfaces:**
- Consumes: `PetDefinition`, `PetID`, elapsed `TimeInterval`, stable `animationPhaseOffset`, and the Idle Motion/reaction enabled flag.
- Produces: `PetAmbientEffectKind`, `PetAmbientParticleSample`, `PetAmbientEffectSample`, `PetAmbientEffectKind.sample(at:phaseOffset:isEnabled:)`, and `PetDefinition.ambientEffect`.

- [ ] **Step 1: Write failing core behavior tests**

Create `PetAmbientEffectTests.swift` with tests that require downward snow/rain travel and wrap, rightward wind travel and edge fading, a short lightning pulse, deterministic samples, and disabled-state freezing:

```swift
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
```

Extend `PetDefinitionTests`:

```swift
@Test
func cloudDefinitionsSelectTheirAmbientEffects() throws {
    #expect(try #require(PetCatalog.definition(for: .cuteCloud)).ambientEffect == .none)
    #expect(try #require(PetCatalog.definition(for: .nimbusCloud)).ambientEffect == .storm)
    #expect(try #require(PetCatalog.definition(for: .cirrusCloud)).ambientEffect == .wind)
    #expect(try #require(PetCatalog.definition(for: .lenticularCloud)).ambientEffect == .none)
    #expect(try #require(PetCatalog.definition(for: .snowCloud)).ambientEffect == .snow)
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter PetAmbientEffectTests
swift test --filter cloudDefinitionsSelectTheirAmbientEffects
```

Expected: compilation fails because the ambient-effect types and `PetDefinition.ambientEffect` do not exist.

- [ ] **Step 3: Implement the pure sampler**

Create `PetAmbientEffect.swift` with public value types and a deterministic sampler. Use fixed seed tuples for each effect, normalized wrapping with `value - floor(value)`, an edge fade for wind, and a triangular double-pulse for lightning. Disabled sampling must use elapsed zero and ignore phase offset.

Required signatures:

```swift
public enum PetAmbientEffectKind: Equatable, Sendable {
    case none
    case storm
    case wind
    case snow

    public func sample(
        at elapsed: TimeInterval,
        phaseOffset: Double,
        isEnabled: Bool
    ) -> PetAmbientEffectSample
}

public struct PetAmbientParticleSample: Equatable, Identifiable, Sendable {
    public let id: Int
    public let x: Double
    public let y: Double
    public let opacity: Double
    public let scale: Double
    public let stretch: Double
    public let rotationDegrees: Double
}

public struct PetAmbientEffectSample: Equatable, Sendable {
    public let particles: [PetAmbientParticleSample]
    public let lightningIntensity: Double
    public static let none = PetAmbientEffectSample(particles: [], lightningIntensity: 0)
}
```

Use these exact motion envelopes:

- Snow: six lanes, 3.8-second base cycle, local `y` from `4...52`, sinusoidal drift, rotation, and opacity at least `0.58`.
- Storm: seven lanes, 1.25-second base rain cycle, local `y` from `7...48`, and a 4.8-second lightning phase with pulse centers at `0.16` and `0.24` after a `0.55` phase bias.
- Wind: four lanes, 4.2-second base cycle, local `x` from `-58...58`, sinusoidal vertical drift, and opacity faded over the first/last `0.12` of travel.

- [ ] **Step 4: Add definition metadata**

Add this property and defaulted initializer parameter to `PetDefinition`:

```swift
public let ambientEffect: PetAmbientEffectKind

public init(
    id: PetID,
    displayName: String,
    category: PetCategoryDescriptor,
    capabilities: PetCapabilities,
    defaults: PetDefaultConfiguration,
    presentation: PetPresentationConfiguration,
    ambientEffect: PetAmbientEffectKind = .none,
    renderSource: PetRenderSource
)
```

Set `ambientEffect: .storm` on Nimbus, `.wind` on Cirrus, and `.snow` on Snow Cloud. Leave Cumulus and Lenticular on the default `.none`.

- [ ] **Step 5: Run GREEN and commit**

Run:

```bash
swift test --filter PetAmbientEffectTests
swift test --filter PetDefinitionTests
```

Expected: all selected tests pass with zero failures.

Commit only the task files:

```bash
git add Sources/PetsCore/Pets/PetAmbientEffect.swift Sources/PetsCore/Pets/PetDefinition.swift Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetAmbientEffectTests.swift Tests/PetsCoreTests/Pets/PetDefinitionTests.swift
git commit -m "feat: model cloud ambient effects"
```

---

### Task 2: SwiftUI Voxel Effect Layers

**Files:**
- Create: `Sources/Pets/PetAmbientEffects.swift`
- Modify: `Sources/Pets/PetSprites.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`

**Interfaces:**
- Consumes: `PetDefinition.ambientEffect`, `PetAmbientEffectSample`, the existing 128-unit sprite geometry, body `PetMotionSample`, and `isAmbientMotionEnabled`.
- Produces: `PetAmbientEffectView`, background/foreground effect composition, and independent runtime movement under the existing pixelation boundary.

- [ ] **Step 1: Write failing renderer wiring tests**

Extend `PetSpriteSourceTests`:

```swift
@Test
func petSpriteComposesIndependentAmbientEffectsInsideWholePetMotion() throws {
    let source = try source("Sources/Pets/PetSprites.swift")

    #expect(source.contains("definition.ambientEffect.sample("))
    #expect(source.contains("PetAmbientEffectView("))
    #expect(source.contains("layer: .background"))
    #expect(source.contains("layer: .foreground"))
    #expect(source.contains("isEnabled: isAmbientMotionEnabled"))

    let background = try #require(source.range(of: "layer: .background"))
    let body = try #require(source.range(of: "blendedPetImage("))
    let foreground = try #require(source.range(of: "layer: .foreground"))
    let wholePetMotion = try #require(source.range(of: "PetMotionSampleModifier(sample: motion)"))

    #expect(background.lowerBound < body.lowerBound)
    #expect(body.lowerBound < foreground.lowerBound)
    #expect(foreground.lowerBound < wholePetMotion.lowerBound)
}

@Test
func ambientEffectViewContainsStormWindAndSnowRenderers() throws {
    let source = try source("Sources/Pets/PetAmbientEffects.swift")

    #expect(source.contains("case (.storm, .foreground)"))
    #expect(source.contains("case (.wind, .background)"))
    #expect(source.contains("case (.snow, .foreground)"))
    #expect(source.contains("VoxelRaindrop"))
    #expect(source.contains("VoxelLightningBolt"))
    #expect(source.contains("VoxelWindRibbon"))
    #expect(source.contains("VoxelSnowflake"))
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter PetSpriteSourceTests
```

Expected: the two new tests fail because the sampler call, view, and source file do not exist.

- [ ] **Step 3: Implement the effect view**

Create `PetAmbientEffects.swift` with:

```swift
import PetsCore
import SwiftUI

enum PetAmbientEffectLayer {
    case background
    case foreground
}

struct PetAmbientEffectView: View {
    let kind: PetAmbientEffectKind
    let sample: PetAmbientEffectSample
    let unit: CGFloat
    let layer: PetAmbientEffectLayer

    @ViewBuilder
    var body: some View {
        switch (kind, layer) {
        case (.storm, .foreground):
            storm
        case (.wind, .background):
            wind
        case (.snow, .foreground):
            snow
        default:
            EmptyView()
        }
    }
}
```

Implement bounded `ForEach(sample.particles)` renderers using `position(x:y:)` in the 128-unit coordinate space:

- `VoxelSnowflake`: crossed thin rectangles with white/ice-blue styling.
- `VoxelRaindrop`: a cyan rectangular drop with a small lighter cap.
- `VoxelLightningBolt`: a closed gold zig-zag `Path`, opacity and glow driven by `lightningIntensity`.
- `VoxelWindRibbon`: two offset pale horizontal rectangles with lengths driven by `stretch`.

Every effect view must call `.allowsHitTesting(false)` and render no accessibility element.

- [ ] **Step 4: Integrate effects around the pet body**

In `AssetPetSprite.renderedFrame(at:)`, sample:

```swift
let ambient = definition.ambientEffect.sample(
    at: rawElapsed,
    phaseOffset: visualContext.animationPhaseOffset,
    isEnabled: isAmbientMotionEnabled
)
```

Add `definition.ambientEffect != .none` to `usesTimeline`. Replace the body-only transform chain with one composite:

```swift
ZStack {
    PetAmbientEffectView(
        kind: definition.ambientEffect,
        sample: ambient,
        unit: unit,
        layer: .background
    )

    blendedPetImage(
        primary: primaryImage,
        secondary: secondaryImage,
        secondaryOpacity: playback.secondaryOpacity
    )

    PetAmbientEffectView(
        kind: definition.ambientEffect,
        sample: ambient,
        unit: unit,
        layer: .foreground
    )
}
.scaleEffect(definition.presentation.contentScale)
.offset(
    x: definition.presentation.anchorX * unit,
    y: definition.presentation.anchorY * unit
)
.modifier(PetMotionSampleModifier(sample: motion))
.modifier(PetReactionVisualModifier(...))
```

- [ ] **Step 5: Run GREEN and commit**

Run:

```bash
swift test --filter PetSpriteSourceTests
swift test --filter PetAmbientEffectTests
swift build
```

Expected: all selected tests and the build pass.

Commit only the task files:

```bash
git add Sources/Pets/PetAmbientEffects.swift Sources/Pets/PetSprites.swift Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift
git commit -m "feat: animate cloud weather details"
```

---

### Task 3: Full and Runtime Verification

**Files:**
- Verify: all files from Tasks 1 and 2
- Preserve: unrelated working-tree edits

**Interfaces:**
- Consumes: completed core sampler, definition metadata, SwiftUI effect renderer, package tests, and the app bundle script.
- Produces: verified build/test state and a running current `Pets.app` bundle.

- [ ] **Step 1: Run the full repository gate**

Run:

```bash
./scripts/check.sh
```

Expected: the full Swift test suite and `swift build` pass with zero failures.

- [ ] **Step 2: Rebuild and launch the packaged app**

Run:

```bash
./scripts/run_app.sh --verify
```

Expected: the script builds `Pets.app`, verifies the bundle, launches the current executable, and reports success.

- [ ] **Step 3: Inspect actual overlay-scale behavior**

With Nimbus, Cirrus, and Snow Cloud selected in turn, verify:

- Snowflakes visibly descend and wrap independently of the breathing body.
- Raindrops visibly descend while lightning produces a brief double pulse.
- Wind ribbons visibly travel left-to-right independently of Cirrus sway.
- Turning Idle Motion off freezes every effect.
- Existing hover, reaction, pixelation, and transparent-window behavior remain intact.

If any effect is unreadable at the existing `0.72` overlay scale, adjust only its renderer sizes or sampler amplitude, rerun the focused tests, and repeat this inspection.

- [ ] **Step 4: Final diff and status audit**

Run:

```bash
git status --short
git diff --check
git log -n 3 --oneline
```

Expected: only the user’s pre-existing sidebar/settings edits remain uncommitted; ambient-effect work is committed and the diff contains no whitespace errors.
