# Pet Definition Classes and Generated Art Packs Implementation Plan

> **Superseded:** The user replaced the phased multi-pet migration with a single-pet product direction on 2026-07-11. The completed implementation keeps only generated Cute Cloud, removes all legacy pets and selection UI, and normalizes saved legacy IDs to Cute Cloud.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the duplicated built-in pet catalog/render routing with immutable concrete pet definition classes, add optional asset-backed animation states with idle fallback, and migrate Cute Cloud to generated voxel-style art while all other pets retain their legacy renderers.

**Architecture:** `PetInstance` remains the Codable user-configuration value. `PetCatalog` registers one immutable `PetDefinition` subclass per existing `PetID`; each definition composes capabilities, defaults, presentation, and either an asset pack or a legacy render family. `PetSprite` resolves a definition and visual context, then delegates to an asset animation player or the compatibility renderer.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftPM resources, ImageIO, `swift-testing`, OpenAI built-in image generation with local chroma-key removal.

## Global Constraints

- Preserve all 17 existing `PetID` raw values, display names, category order, and pet order.
- Preserve the `PetInstance` Codable schema and existing `UserDefaults` data.
- Require idle artwork; busy, waiting, excited, and sleeping artwork are optional.
- Resolve every missing optional state directly to idle.
- Support only built-in pets in this phase.
- Migrate only Cute Cloud to generated artwork in this phase.
- Keep the other 16 pets on their existing SwiftUI renderers.
- Use 512x512 transparent PNG production frames with no baked background, text, watermark, glow, or cast shadow.
- Keep generated assets consistent with the supplied soft 3D voxel/chibi reference.
- Use TDD for behavior and configuration changes.
- Preserve unrelated working-tree changes.

---

### Task 1: Core Definition and Animation Types

**Files:**
- Create: `Sources/PetsCore/Pets/PetDefinition.swift`
- Create: `Sources/PetsCore/Pets/PetAnimation.swift`
- Test: `Tests/PetsCoreTests/Pets/PetDefinitionTests.swift`
- Test: `Tests/PetsCoreTests/Pets/PetAnimationTests.swift`

**Interfaces:**
- Consumes: `PetID`, `PetSpritePixelation`, `PetAnimationSettings`, `PetRenderFamily`
- Produces: `PetDefinition`, `PetCategoryDescriptor`, `PetCapabilities`, `PetDefaultConfiguration`, `PetPresentationConfiguration`, `PetRenderSource`, `PetVisualState`, `PetAnimationFrame`, `PetAnimation`, `PetArtPack`, `PetMotionPreset`

- [ ] **Step 1: Add failing animation model tests**

```swift
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
    func animationRequiresAtLeastOnePositiveDurationFrame() throws {
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
    }

    @Test
    func frameIndexUsesConfiguredDurationsAndLooping() throws {
        let animation = try #require(PetAnimation(
            frames: [
                PetAnimationFrame(resourceName: "0", resourceExtension: "png", subdirectory: "x", duration: 0.25),
                PetAnimationFrame(resourceName: "1", resourceExtension: "png", subdirectory: "x", duration: 0.75)
            ],
            loopBehavior: .loop,
            motion: .none
        ))

        #expect(animation.frameIndex(at: 0.10) == 0)
        #expect(animation.frameIndex(at: 0.50) == 1)
        #expect(animation.frameIndex(at: 1.10) == 0)
    }
}
```

- [ ] **Step 2: Run the animation tests and verify RED**

Run: `swift test --filter PetAnimationTests`

Expected: FAIL because the animation types do not exist.

- [ ] **Step 3: Implement the animation value model**

Implement `PetVisualState`, `PetMotionPreset`, `PetAnimationLoopBehavior`, `PetAnimationFrame`, `PetAnimation`, and `PetArtPack` in `Sources/PetsCore/Pets/PetAnimation.swift`.

Required API:

```swift
public enum PetVisualState: String, CaseIterable, Sendable {
    case idle, busy, waiting, excited, sleeping
}

public enum PetMotionPreset: Equatable, Sendable {
    case none, breathe, bob, sway, pulse
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
}

public struct PetAnimation: Equatable, Sendable {
    public let frames: [PetAnimationFrame]
    public let loopBehavior: PetAnimationLoopBehavior
    public let motion: PetMotionPreset
    public init?(frames: [PetAnimationFrame], loopBehavior: PetAnimationLoopBehavior, motion: PetMotionPreset)
    public func frameIndex(at elapsed: TimeInterval) -> Int
}

public struct PetArtPack: Equatable, Sendable {
    public let idle: PetAnimation
    public let busy: PetAnimation?
    public let waiting: PetAnimation?
    public let excited: PetAnimation?
    public let sleeping: PetAnimation?
    public func animation(for state: PetVisualState) -> PetAnimation?
    public func resolvedAnimation(for state: PetVisualState) -> PetAnimation
}
```

`frameIndex(at:)` must sum frame durations, use modulo for `.loop`, clamp for `.once`, and return zero for a one-frame animation.

- [ ] **Step 4: Add failing definition tests**

```swift
import Testing
@testable import PetsCore

@Suite
struct PetDefinitionTests {
    @Test
    func definitionKeepsDeveloperConfigurationOutOfPetInstance() {
        let definition = StubPetDefinition()
        let instance = PetInstance.defaultInstance()

        #expect(definition.id == .cuteCloud)
        #expect(definition.defaults.pixelation == .off)
        #expect(instance.petID == definition.id)
    }
}

private final class StubPetDefinition: PetDefinition, @unchecked Sendable {
    init() {
        super.init(
            id: .cuteCloud,
            displayName: "Cute Cloud",
            category: .cloudPets,
            capabilities: PetCapabilities(
                maximumPixelation: .medium,
                supportsStatusMoods: true,
                supportsHoverExcitement: true
            ),
            defaults: .standard,
            presentation: .standard,
            renderSource: .legacy(.cuteCloud)
        )
    }
}
```

- [ ] **Step 5: Run the definition tests and verify RED**

Run: `swift test --filter PetDefinitionTests`

Expected: FAIL because the definition types do not exist.

- [ ] **Step 6: Implement immutable definition configuration**

Implement the following in `Sources/PetsCore/Pets/PetDefinition.swift`:

```swift
public struct PetCategoryDescriptor: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let order: Int
    public static let cloudPets: Self
    public static let workspacePets: Self
    public static let naturePets: Self
    public static let cozyPets: Self
    public static let voxelPets: Self
}

public struct PetCapabilities: Equatable, Sendable {
    public let maximumPixelation: PetSpritePixelation
    public let supportsStatusMoods: Bool
    public let supportsHoverExcitement: Bool
}

public struct PetDefaultConfiguration: Equatable, Sendable {
    public let pixelation: PetSpritePixelation
    public let sessionContextLineCount: Int
    public let animationSettings: PetAnimationSettings
    public static let standard: Self
}

public struct PetPresentationConfiguration: Equatable, Sendable {
    public let contentScale: Double
    public let anchorX: Double
    public let anchorY: Double
    public let shadowWidth: Double
    public let shadowHeight: Double
    public let shadowOpacity: Double
    public let transitionDuration: TimeInterval
    public static let standard: Self
}

public enum PetRenderSource: Equatable, Sendable {
    case assetPack(PetArtPack)
    case legacy(PetRenderFamily)
}

open class PetDefinition: @unchecked Sendable {
    public let id: PetID
    public let displayName: String
    public let category: PetCategoryDescriptor
    public let capabilities: PetCapabilities
    public let defaults: PetDefaultConfiguration
    public let presentation: PetPresentationConfiguration
    public let renderSource: PetRenderSource
}
```

- [ ] **Step 7: Run both focused suites and verify GREEN**

Run: `swift test --filter PetAnimationTests && swift test --filter PetDefinitionTests`

Expected: PASS.

- [ ] **Step 8: Commit the core model**

```bash
git add Sources/PetsCore/Pets/PetAnimation.swift Sources/PetsCore/Pets/PetDefinition.swift Tests/PetsCoreTests/Pets/PetAnimationTests.swift Tests/PetsCoreTests/Pets/PetDefinitionTests.swift
git commit -m "feat: add pet definition and animation models"
```

---

### Task 2: Concrete Built-In Definitions and Derived Catalog

**Files:**
- Create: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Create: `Sources/PetsCore/Pets/Definitions/WorkspacePetDefinitions.swift`
- Create: `Sources/PetsCore/Pets/Definitions/NaturePetDefinitions.swift`
- Create: `Sources/PetsCore/Pets/Definitions/CozyPetDefinitions.swift`
- Create: `Sources/PetsCore/Pets/Definitions/VoxelPetDefinitions.swift`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Sources/PetsCore/Pets/PetInstance.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetInstanceTests.swift`

**Interfaces:**
- Consumes: Task 1 definition types and every existing `PetID`
- Produces: one final definition class per built-in pet, `PetCatalog.definitions`, `PetCatalog.definition(for:)`, derived compatibility APIs

- [ ] **Step 1: Add failing registry compatibility tests**

Add tests that assert:

```swift
@Test
func registryContainsEveryExistingPetExactlyOnceInExistingOrder() {
    #expect(PetCatalog.definitions.map(\.id) == [
        .cuteCloud, .classicCloud, .helperCloud, .sleepCloud, .focusCloud,
        .codeBot, .terminalCube, .bookstackBuddy,
        .sproutBuddy, .pebblePal, .pocketStar,
        .teaCup, .nightLamp, .tinyRocket,
        .voxelCat, .voxelSlime, .voxelDragon
    ])
    #expect(Set(PetCatalog.definitions.map(\.id)).count == 17)
}

@Test
func catalogCompatibilityAPIsDelegateToDefinitions() throws {
    let cuteCloud = try #require(PetCatalog.definition(for: .cuteCloud))
    #expect(cuteCloud is CuteCloudPetDefinition)
    #expect(PetCatalog.displayName(for: .cuteCloud) == cuteCloud.displayName)
    #expect(PetCatalog.maximumPixelation(for: .cuteCloud) == cuteCloud.capabilities.maximumPixelation)
    #expect(PetCatalog.renderFamily(for: .cuteCloud) == .cuteCloud)
}
```

Add a `PetInstanceTests` expectation that `defaultInstance()` uses the registered definition defaults.

- [ ] **Step 2: Run catalog and instance tests and verify RED**

Run: `swift test --filter PetCatalogTests && swift test --filter PetInstanceTests`

Expected: FAIL because definitions and registry lookup do not exist.

- [ ] **Step 3: Add all 17 concrete definition classes**

Create one `final` subclass for each existing ID. Each class passes the current display name, category, legacy family, and maximum pixelation to `PetDefinition`.

Use `.standard` defaults and presentation initially. Use the current render-family mapping exactly:

- Cute Cloud -> `.cuteCloud`
- Classic/Helper/Sleep/Focus Cloud -> `.cloud`
- Code Bot/Terminal Cube/Bookstack Buddy -> `.workspace`
- Sprout Buddy/Pebble Pal/Pocket Star -> `.nature`
- Tea Cup/Night Lamp/Tiny Rocket -> `.cozy`
- Voxel Cat/Voxel Slime/Voxel Dragon -> `.voxel`

Mark every subclass `final` and `@unchecked Sendable` because the immutable base class is shared.

- [ ] **Step 4: Rebuild PetCatalog from the definition registry**

Replace the hand-authored entries and category membership with:

```swift
public static let definitions: [PetDefinition] = [
    CuteCloudPetDefinition(),
    ClassicCloudPetDefinition(),
    HelperCloudPetDefinition(),
    SleepCloudPetDefinition(),
    FocusCloudPetDefinition(),
    CodeBotPetDefinition(),
    TerminalCubePetDefinition(),
    BookstackBuddyPetDefinition(),
    SproutBuddyPetDefinition(),
    PebblePalPetDefinition(),
    PocketStarPetDefinition(),
    TeaCupPetDefinition(),
    NightLampPetDefinition(),
    TinyRocketPetDefinition(),
    VoxelCatPetDefinition(),
    VoxelSlimePetDefinition(),
    VoxelDragonPetDefinition()
]

private static let definitionsByID = Dictionary(
    uniqueKeysWithValues: definitions.map { ($0.id, $0) }
)
```

Derive `entries`, `builtInCategories`, `builtInPetIDs`, names, category, maximum pixelation, and legacy render family from definitions. For `.assetPack`, `renderFamily(for:)` returns `nil`; this compatibility method is only for the temporary legacy path.

- [ ] **Step 5: Make default PetInstance configuration definition-driven**

Update `PetInstance.defaultInstance()` to read the default definition's pixelation, session context line count, and animation settings while keeping the persisted struct fields unchanged.

- [ ] **Step 6: Run the focused tests and verify GREEN**

Run: `swift test --filter PetCatalogTests && swift test --filter PetInstanceTests`

Expected: PASS with all existing catalog assertions unchanged.

- [ ] **Step 7: Commit the registry migration**

```bash
git add Sources/PetsCore/Pets/Definitions Sources/PetsCore/Pets/PetCatalog.swift Sources/PetsCore/Pets/PetInstance.swift Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetInstanceTests.swift
git commit -m "refactor: register built-in pet definitions"
```

---

### Task 3: Visual Context and State Resolution

**Files:**
- Create: `Sources/PetsCore/Pets/PetVisualStateResolver.swift`
- Create: `Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift`

**Interfaces:**
- Consumes: `HarnessSessionStatus`, `PetAnimationSettings`, `PetVisualState`
- Produces: `PetVisualContext`, `PetVisualStateResolver.requestedState(for:)`

- [ ] **Step 1: Write failing state-priority and fallback-input tests**

```swift
import Testing
@testable import PetsCore

@Suite
struct PetVisualStateResolverTests {
    @Test(arguments: [
        (PetVisualContext(status: .waiting, hasActiveSessions: true, isHovered: true, animationSettings: .default), .excited),
        (PetVisualContext(status: .waiting, hasActiveSessions: true, isHovered: false, animationSettings: .default), .waiting),
        (PetVisualContext(status: .busy, hasActiveSessions: true, isHovered: false, animationSettings: .default), .busy),
        (PetVisualContext(status: .idle, hasActiveSessions: true, isHovered: false, animationSettings: .default), .idle),
        (PetVisualContext(status: .unknown, hasActiveSessions: false, isHovered: false, animationSettings: .default), .sleeping)
    ])
    func resolvesApprovedPriority(input: (PetVisualContext, PetVisualState)) {
        #expect(PetVisualStateResolver.requestedState(for: input.0) == input.1)
    }

    @Test
    func disabledStatusMoodsRequestIdle() {
        let settings = PetAnimationSettings(
            isHoverBounceEnabled: false,
            isIdleMotionEnabled: true,
            areStatusMoodsEnabled: false
        )
        let context = PetVisualContext(
            status: .busy,
            hasActiveSessions: true,
            isHovered: false,
            animationSettings: settings
        )
        #expect(PetVisualStateResolver.requestedState(for: context) == .idle)
    }
}
```

- [ ] **Step 2: Run the resolver suite and verify RED**

Run: `swift test --filter PetVisualStateResolverTests`

Expected: FAIL because the resolver does not exist.

- [ ] **Step 3: Implement the visual context and resolver**

Implement the exact approved priority. Hover excitement only wins when `isHoverBounceEnabled` is true. Status moods disabled returns idle before checking session status. No active sessions returns sleeping.

- [ ] **Step 4: Run the resolver suite and verify GREEN**

Run: `swift test --filter PetVisualStateResolverTests`

Expected: PASS.

- [ ] **Step 5: Commit state resolution**

```bash
git add Sources/PetsCore/Pets/PetVisualStateResolver.swift Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift
git commit -m "feat: resolve pet visual states"
```

---

### Task 4: SwiftPM Resource Plumbing and Validation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PetsCore/Pets/PetArtResourceLocator.swift`
- Create: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Create later in Task 6: `Sources/PetsCore/Resources/PetArt/cute-cloud/...`

**Interfaces:**
- Consumes: `PetAnimationFrame`, `Bundle.module`
- Produces: `PetArtResourceLocator.url(for:)`, validation helpers used by tests and renderer

- [ ] **Step 1: Add a temporary fixture PNG and failing locator tests**

Use a tiny committed test fixture under `Sources/PetsCore/Resources/PetArt/test/idle/frame-000.png` only for the RED/GREEN cycle, then remove it when real Cute Cloud resources exist.

Test that a known `PetAnimationFrame` resolves to a URL and a nonexistent frame returns `nil`.

- [ ] **Step 2: Run the resource tests and verify RED**

Run: `swift test --filter PetArtResourceTests`

Expected: FAIL because `PetsCore` has no resource declaration or locator.

- [ ] **Step 3: Add the resource bundle and locator**

Update `Package.swift`:

```swift
.target(
    name: "PetsCore",
    resources: [.copy("Resources/PetArt")]
)
```

Implement `PetArtResourceLocator` with `Bundle.module.url(forResource:withExtension:subdirectory:)`.

- [ ] **Step 4: Add validation tests for production frames**

Using `CGImageSource` or `NSBitmapImageRep`, validate every asset-pack frame registered in `PetCatalog`:

- URL exists.
- Width and height are 512.
- Alpha is present.
- Four corner alpha values are zero.

The suite must skip legacy definitions and enumerate every frame of each asset state.

- [ ] **Step 5: Run locator tests and verify GREEN for the fixture**

Run: `swift test --filter PetArtResourceTests`

Expected: PASS for the locator fixture; production asset enumeration remains empty until Task 6 switches Cute Cloud.

- [ ] **Step 6: Commit resource plumbing**

```bash
git add Package.swift Sources/PetsCore/Pets/PetArtResourceLocator.swift Sources/PetsCore/Resources/PetArt/test Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: add pet art resource validation"
```

---

### Task 5: Asset Renderer and Legacy Adapter

**Files:**
- Modify: `Sources/Pets/PetSprites.swift`
- Modify: `Sources/Pets/PetOverlayView.swift`
- Modify: `Sources/Pets/PetSettingsViews.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

**Interfaces:**
- Consumes: `PetDefinition`, `PetRenderSource`, `PetVisualContext`, `PetAnimation`, `PetArtResourceLocator`
- Produces: `AssetPetSprite`, `LegacyPetSpriteAdapter`, definition-driven `PetSprite`

- [ ] **Step 1: Add failing source integration tests**

Assert that:

```swift
#expect(source.contains("switch definition.renderSource"))
#expect(source.contains("AssetPetSprite("))
#expect(source.contains("LegacyPetSpriteAdapter("))
#expect(source.contains("PetVisualStateResolver.requestedState"))
#expect(overlaySource.contains("PetVisualContext("))
#expect(!overlaySource.contains("status: spriteStatus"))
```

Update existing source tests that assume direct `PetCatalog.renderFamily(for:)` routing.

- [ ] **Step 2: Run sprite/overlay source tests and verify RED**

Run: `swift test --filter PetSpriteSourceTests && swift test --filter PetOverlayTransparencyTests`

Expected: FAIL because rendering still routes directly by render family.

- [ ] **Step 3: Refactor PetSprite into definition-driven routing**

Change `PetSprite` to accept:

```swift
let petID: PetID
let visualContext: PetVisualContext
let pixelation: PetSpritePixelation
```

Resolve `PetCatalog.definition(for:)`. Route `.assetPack` to `AssetPetSprite` and `.legacy` to `LegacyPetSpriteAdapter`. Preserve the existing unknown-ID fallback.

- [ ] **Step 4: Implement the legacy adapter**

Move the existing family switch behind `LegacyPetSpriteAdapter`. Derive the legacy status and excitement inputs from `PetVisualContext`. Preserve the existing pixelation wrapper and current hover transform for legacy pets.

- [ ] **Step 5: Implement the asset animation player**

`AssetPetSprite` must:

- Resolve the requested state with `PetVisualStateResolver`.
- Resolve missing animation to idle with `PetArtPack`.
- Load frames through a URL-keyed `NSCache` outside the definition registry.
- Render a static first frame when animation is disabled or the animation has one frame.
- Use `TimelineView` and `PetAnimation.frameIndex(at:)` for multiple frames.
- Apply definition scale and anchor.
- Draw the definition-configured runtime shadow.
- Apply the selected motion preset only when animation is enabled.
- Crossfade on visual-state change.
- Render a visible placeholder containing the pet ID if idle cannot load.

- [ ] **Step 6: Pass visual context from every UI surface**

Overlay context uses the real `store.dominantStatus`, `!store.visibleSessions.isEmpty`, hover state, and instance settings. Settings preview uses its supplied dominant status and instance settings. Picker preview uses a non-hovered idle preview context.

Remove the outer overlay bounce for asset pets; keep equivalent behavior inside the legacy adapter.

- [ ] **Step 7: Derive capability labels from definitions**

Only show the “Moods” capability tag when the selected definition supports status moods. Preserve existing labels for all current pets.

- [ ] **Step 8: Run focused renderer/source tests and verify GREEN**

Run: `swift test --filter PetSpriteSourceTests && swift test --filter PetOverlayTransparencyTests`

Expected: PASS.

- [ ] **Step 9: Commit renderer routing**

```bash
git add Sources/Pets/PetSprites.swift Sources/Pets/PetOverlayView.swift Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift
git commit -m "feat: route pet definitions through asset renderer"
```

---

### Task 6: Generate and Normalize Cute Cloud State Art

**Files:**
- Create: `tmp/imagegen/cute-cloud-*.png` during generation; remove after acceptance
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/idle/frame-000.png`
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/busy/frame-000.png`
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/waiting/frame-000.png`
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/excited/frame-000.png`
- Create: `Sources/PetsCore/Resources/PetArt/cute-cloud/sleeping/frame-000.png`
- Create: `docs/assets/cute-cloud-state-contact-sheet.png`
- Remove: `Sources/PetsCore/Resources/PetArt/test/`

**Interfaces:**
- Consumes: supplied reference image, built-in image generation, chroma-key removal helper
- Produces: five normalized production state frames and one review contact sheet

- [ ] **Step 1: Generate the canonical Cute Cloud state sheet**

Use the built-in image generation path with the supplied reference image as style and identity guidance.

Prompt specification:

```text
Use case: stylized-concept
Asset type: macOS desktop pet animation state art
Primary request: Create a consistent five-state character sheet for the same Cute Cloud character: idle, busy, waiting, excited, sleeping.
Input images: Image 1 is the definitive style, material, camera, proportions, face, and identity reference.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background, identical in every cell.
Subject: rounded chibi cloud assembled from small softly beveled white voxels; glossy black square eyes with tiny white highlights; tiny centered mouth; subtle pink blush; short rounded voxel arms.
Style/medium: premium soft 3D voxel render, warm cream studio lighting on the character only, near-isometric three-quarter view.
Composition/framing: five evenly spaced isolated full-body states, identical camera angle, scale, floor anchor, and padding; no overlap.
State poses: idle is calm and neutral; busy is focused and working; waiting is attentive and expectant; excited is joyful with raised arms; sleeping has closed eyes and a tucked restful pose.
Constraints: preserve one exact character identity across all states; no cast shadows; no contact shadows; no floor plane; no glow; no text; no labels; no watermark; background must be one perfectly uniform color.
Avoid: redesigning the face, changing voxel size, different camera angles, gradients, reflections, scenery, props, extra characters.
```

- [ ] **Step 2: Inspect identity and layout**

Reject and regenerate once with a single targeted correction if identity, camera, scale, spacing, or green-background uniformity fails.

- [ ] **Step 3: Extract five state cells and remove chroma key**

Crop each cell non-destructively, then run:

```bash
for state in idle busy waiting excited sleeping; do
  python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
    --input "tmp/imagegen/cute-cloud-${state}-source.png" \
    --out "tmp/imagegen/cute-cloud-${state}-alpha.png" \
    --auto-key border \
    --soft-matte \
    --transparent-threshold 12 \
    --opaque-threshold 220 \
    --despill
done
```

Use the bundled image/document runtime only for deterministic cropping, alpha validation, and downscaling. Do not use it to generate or repaint the art.

- [ ] **Step 4: Normalize frames**

Place each extracted subject on a 512x512 transparent canvas. Match visible bounds and floor anchor across all states. Preserve high-quality resampling while keeping voxel edges crisp.

- [ ] **Step 5: Build and inspect the contact sheet**

Create a labeled documentation-only contact sheet showing the five final frames on a neutral checkerboard. Confirm identity, proportions, anchor, alpha edges, and small-size readability.

- [ ] **Step 6: Run resource validation**

Run: `swift test --filter PetArtResourceTests`

Expected: PASS after Task 7 registers the pack; before registration, separately verify image dimensions and alpha with the resource test helper or `sips`/ImageIO.

- [ ] **Step 7: Commit accepted artwork**

```bash
git add Sources/PetsCore/Resources/PetArt/cute-cloud docs/assets/cute-cloud-state-contact-sheet.png
git rm -r Sources/PetsCore/Resources/PetArt/test
git commit -m "art: add cute cloud state pack"
```

---

### Task 7: Register Cute Cloud Asset Pack

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

**Interfaces:**
- Consumes: Task 6 resource paths and Task 1 art model
- Produces: `CuteCloudPetDefinition.renderSource == .assetPack`

- [ ] **Step 1: Add failing Cute Cloud asset-pack tests**

```swift
@Test
func cuteCloudUsesCompleteAssetPackWhileOtherPetsRemainLegacy() throws {
    let cuteCloud = try #require(PetCatalog.definition(for: .cuteCloud))
    guard case let .assetPack(pack) = cuteCloud.renderSource else {
        Issue.record("Cute Cloud must use an asset pack")
        return
    }

    for state in PetVisualState.allCases {
        #expect(pack.animation(for: state) != nil)
    }

    let classic = try #require(PetCatalog.definition(for: .classicCloud))
    #expect(classic.renderSource == .legacy(.cloud))
}
```

- [ ] **Step 2: Run the catalog test and verify RED**

Run: `swift test --filter PetCatalogTests.cuteCloudUsesCompleteAssetPackWhileOtherPetsRemainLegacy`

Expected: FAIL because Cute Cloud still uses `.legacy(.cuteCloud)`.

- [ ] **Step 3: Register all five Cute Cloud animations**

Create one valid one-frame `PetAnimation` per state using the accepted resource paths. Assign restrained motion presets:

- idle -> `.breathe`
- busy -> `.bob`
- waiting -> `.sway`
- excited -> `.pulse`
- sleeping -> `.breathe`

Use `.loop` and state-appropriate durations. Set Cute Cloud capabilities to support moods and hover excitement. Tune presentation scale, anchor, shadow, and crossfade against the normalized frames.

- [ ] **Step 4: Run catalog and resource tests and verify GREEN**

Run: `swift test --filter PetCatalogTests && swift test --filter PetArtResourceTests`

Expected: PASS, including file, dimension, alpha, and transparent-corner checks.

- [ ] **Step 5: Commit Cute Cloud registration**

```bash
git add Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: migrate cute cloud to generated art"
```

---

### Task 8: Full Verification and Packaged App Inspection

**Files:**
- Verify: all changed source, test, resource, and documentation files

**Interfaces:**
- Consumes: Tasks 1-7
- Produces: verified package and rebuilt `.app`

- [ ] **Step 1: Run focused suites**

Run:

```bash
swift test --filter PetAnimationTests
swift test --filter PetDefinitionTests
swift test --filter PetCatalogTests
swift test --filter PetInstanceTests
swift test --filter PetVisualStateResolverTests
swift test --filter PetArtResourceTests
swift test --filter PetSpriteSourceTests
swift test --filter PetOverlayTransparencyTests
```

Expected: every command exits 0.

- [ ] **Step 2: Run the repository check**

Run: `./scripts/check.sh`

Expected: full `swift test` and `swift build` exit 0.

- [ ] **Step 3: Rebuild and verify the app bundle**

Run: `./scripts/run_app.sh --verify`

Expected: the script stages and launches `dist/Pets.app` successfully.

- [ ] **Step 4: Inspect the running UI**

Confirm:

- Cute Cloud renders from the new voxel-style asset in overlay, settings, carousel, and picker.
- Idle, busy, waiting, excited, and sleeping states are reachable and aligned.
- Disabling moods renders idle.
- Disabling animation freezes the first frame and motion.
- The other 16 pets remain available and render through their legacy paths.
- Existing saved instances retain names, positions, visibility, and settings.
- No pet clips at overlay or picker bounds.

- [ ] **Step 5: Inspect repository scope**

Run: `git status --short` and `git diff HEAD~7 --stat`.

Expected: only the approved architecture, tests, Cute Cloud art, generated contact sheet, spec, and plan are present.

- [ ] **Step 6: Final implementation commit if verification required fixes**

If verification required tracked fixes, stage only those scoped files and commit:

```bash
git commit -m "fix: finish pet definition migration"
```
