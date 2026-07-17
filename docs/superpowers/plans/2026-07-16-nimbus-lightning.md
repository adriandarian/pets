# Nimbus Lightning Length and Cadence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enlarge Nimbus lightning to 20 by 50 points and repeat its existing double-flash sequence every 1.8 seconds.

**Architecture:** Keep cadence in the shared `PetAmbientEffectKind.storm` sampler so steady and reaction renderers receive identical lightning intensity. Update the SwiftUI Canvas and Core Animation geometry together, anchoring the current top edge and moving only the bottom edge downward.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI Canvas, Core Animation, Swift Package Manager, macOS 14+

## Global Constraints

- The bolt is 20 points wide and 50 points tall.
- The bolt's top edge stays at its current position; its center moves from 87 to 97.5 points in top-left coordinates.
- The double-flash sequence repeats every 1.8 seconds.
- Pulse shape, relative brightness, per-pet phase offsets, rain behavior, pet motion, and animation efficiency remain unchanged.
- Ambient-motion-disabled behavior continues to return zero lightning intensity.
- Preserve unrelated dirty-worktree changes and do not stage implementation files without separate user authorization.

---

### Task 1: Accelerate the shared lightning sampler

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetAmbientEffectTests.swift:17-27`
- Modify: `Sources/PetsCore/Pets/PetAmbientEffect.swift:138-175`

**Interfaces:**
- Consumes: `PetAmbientEffectKind.storm.sample(at:phaseOffset:isEnabled:) -> PetAmbientEffectSample`
- Produces: A storm sample whose `lightningIntensity` repeats the existing double pulse every 1.8 seconds.

- [ ] **Step 1: Write the failing cadence test**

Replace the existing storm test's pulse sample with two peak samples exactly one new cycle apart:

```swift
@Test
func stormRainFallsInStaggeredLanesAndLightningRepeatsEveryOnePointEightSeconds() {
    let start = PetAmbientEffectKind.storm.sample(at: 0, phaseOffset: 0, isEnabled: true)
    let falling = PetAmbientEffectKind.storm.sample(at: 0.4, phaseOffset: 0, isEnabled: true)
    let firstFlash = PetAmbientEffectKind.storm.sample(at: 1.098, phaseOffset: 0, isEnabled: true)
    let nextFlash = PetAmbientEffectKind.storm.sample(at: 2.898, phaseOffset: 0, isEnabled: true)

    #expect(start.particles.count == 7)
    #expect(Set(start.particles.map(\.x)).count == 7)
    #expect(falling.particles[0].y > start.particles[0].y)
    #expect(start.lightningIntensity == 0)
    #expect(firstFlash.lightningIntensity > 0.95)
    #expect(nextFlash.lightningIntensity > 0.95)
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
swift test --filter stormRainFallsInStaggeredLanesAndLightningRepeatsEveryOnePointEightSeconds
```

Expected: FAIL because the current 4.8-second cycle is not at peak intensity at both `1.098` and `2.898` seconds.

- [ ] **Step 3: Implement the 1.8-second cycle**

In `stormSample`, replace the repeated 4.8-second literals with one local duration:

```swift
let lightningCycleDuration = 1.8
let lightningTime = max(0, elapsed)
    + unitPhase(phaseOffset) * lightningCycleDuration
let lightningPhase = unitPhase(
    lightningTime / lightningCycleDuration + 0.55
)
let firstPulse = triangularPulse(at: lightningPhase, center: 0.16, halfWidth: 0.035)
let secondPulse = triangularPulse(at: lightningPhase, center: 0.24, halfWidth: 0.025) * 0.72
```

Do not change either pulse center, half-width, or brightness multiplier.

- [ ] **Step 4: Run the focused sampler suite and confirm GREEN**

Run:

```bash
swift test --filter PetAmbientEffectTests
```

Expected: all four ambient-effect tests pass.

### Task 2: Extend the bolt downward in both renderers

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`
- Modify: `Sources/Pets/PetAmbientEffects.swift:69-83`
- Modify: `Sources/Pets/PetLayerRenderer.swift:370-379`

**Interfaces:**
- Consumes: `PetAmbientEffectSample.lightningIntensity`
- Produces: Matching 20-by-50-point lightning in SwiftUI Canvas and Core Animation, with a top-left center of 97.5 points.

- [ ] **Step 1: Write the failing renderer-consistency test**

Add this source regression test to `PetSpriteSourceTests`:

```swift
@Test
func stormLightningExtendsDownwardInBothRenderers() {
    let canvasSource = (try? source("Sources/Pets/PetAmbientEffects.swift")) ?? ""
    let layerSource = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

    #expect(canvasSource.contains("translateBy(x: 64 * unit, y: 97.5 * unit)"))
    #expect(canvasSource.contains("lightningPath(width: 20 * unit, height: 50 * unit)"))
    #expect(layerSource.contains("width: 20, height: 50"))
    #expect(layerSource.contains("y: (128 - 97.5) * unit"))
    #expect(layerSource.contains("Self.lightningPath(width: 20, height: 50)"))
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
swift test --filter stormLightningExtendsDownwardInBothRenderers
```

Expected: FAIL because both renderers still use a 13-by-29-point bolt centered at 87.

- [ ] **Step 3: Update SwiftUI Canvas geometry**

Use the new center and height in `drawStorm`:

```swift
lightningContext.translateBy(x: 64 * unit, y: 97.5 * unit)
```

```swift
lightningPath(width: 20 * unit, height: 50 * unit)
```

- [ ] **Step 4: Update Core Animation geometry**

Keep the Core Animation Y-axis mirror while matching the Canvas dimensions:

```swift
lightningLayer.bounds = CGRect(x: 0, y: 0, width: 20, height: 50)
lightningLayer.position = CGPoint(x: 64 * unit, y: (128 - 97.5) * unit)
lightningLayer.path = Self.lightningPath(width: 20, height: 50)
```

- [ ] **Step 5: Run both renderer suites and confirm GREEN**

Run:

```bash
swift test --filter PetSpriteSourceTests
swift test --filter PetAmbientEffectTests
```

Expected: both suites pass, including the cadence and renderer-consistency regressions.

### Task 3: Verify, package, and safely relaunch Pets

**Files:**
- Update generated bundle executable: `dist/Pets.app/Contents/MacOS/Pets`

**Interfaces:**
- Consumes: SwiftPM executable product `Pets`
- Produces: A running `dist/Pets.app` whose packaged executable matches `.build/debug/Pets`.

- [ ] **Step 1: Run the full repository check**

Run:

```bash
./scripts/check.sh
```

Expected: all Swift tests pass and the debug executable builds successfully.

- [ ] **Step 2: Check patch integrity**

Run:

```bash
git diff --check
```

Expected: exit code 0 with no whitespace errors.

- [ ] **Step 3: Quit normally, package the fresh executable, and relaunch**

Use an application-level quit instead of force-killing the process:

```bash
/usr/bin/osascript -e 'tell application id "local.pets.Pets" to quit'
mkdir -p dist/Pets.app/Contents/MacOS
cp .build/debug/Pets dist/Pets.app/Contents/MacOS/Pets
chmod +x dist/Pets.app/Contents/MacOS/Pets
plutil -lint dist/Pets.app/Contents/Info.plist
/usr/bin/open -n dist/Pets.app
```

Expected: the plist is valid and macOS opens the packaged app normally.

- [ ] **Step 4: Verify the live bundle matches the build output**

Run:

```bash
pgrep -x Pets
shasum .build/debug/Pets dist/Pets.app/Contents/MacOS/Pets
```

Expected: `pgrep` returns a live PID and both SHA-1 hashes are identical.
