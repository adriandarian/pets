# Tesslings Pet Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Knotling, Prismite, and Orbitling as a fully animated, asset-backed Tesslings family in the Pets catalog and collection system.

**Architecture:** Extend the existing `PetID`, `PetCategoryDescriptor`, `PetDefinition`, and `PetCatalog` registry. Each Tessling uses the current `PetArtPack` and asset renderer with state-specific transparent PNG sequences; no new renderer or persistence schema is introduced.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Swift Testing, SwiftPM resources, built-in image generation, ImageMagick, Pillow-based chroma-key removal.

## Global Constraints

- Support macOS 14 and newer.
- Add exactly three Tesslings: Knotling, Prismite, and Orbitling.
- Keep the three outer silhouettes and component arrangements visibly distinct.
- Use `knotling`, `prismite`, and `orbitling` as the persisted raw IDs.
- Use common, rare, and legendary rarities respectively.
- Allow `.chunky` pixelation and enable status moods and hover excitement for all three.
- Use the existing `.assetPack` render source and existing runtime completion/error reactions.
- Ship eight idle, four busy, four waiting, five excited, and four sleeping frames per pet.
- Every production frame must be a 512x512 RGBA PNG with transparent corners and no baked background, floor, text, watermark, shadow, or external glow.
- Use the built-in image-generation path and chroma-key removal; do not switch to CLI true transparency without explicit user authorization.
- Preserve existing collection persistence and do not grandfather the new IDs into owned collections.

---

### Task 1: Add Tessling identifiers and category metadata

**Files:**
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Sources/PetsCore/Pets/PetDefinition.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`

**Interfaces:**
- Consumes: existing `PetID` raw-value persistence and `PetCategoryDescriptor` ordering.
- Produces: `PetID.knotling`, `PetID.prismite`, `PetID.orbitling`, and `PetCategoryDescriptor.tesslings`.

- [ ] **Step 1: Write the failing identifier and category test**

Add this test to `PetCatalogTests` without registering definitions yet:

```swift
@Test
func tesslingIdentifiersAndCategoryMetadataAreStable() {
    #expect(PetID.knotling.rawValue == "knotling")
    #expect(PetID.prismite.rawValue == "prismite")
    #expect(PetID.orbitling.rawValue == "orbitling")
    #expect(PetCategoryDescriptor.tesslings.id == "tesslings")
    #expect(PetCategoryDescriptor.tesslings.displayName == "Tesslings")
    #expect(PetCategoryDescriptor.tesslings.order == 1)
}
```

- [ ] **Step 2: Run the focused test and verify the red state**

Run:

```bash
swift test --filter PetCatalogTests.tesslingIdentifiersAndCategoryMetadataAreStable
```

Expected: compilation fails because the three IDs and `.tesslings` descriptor do not exist.

- [ ] **Step 3: Add the three IDs**

Add beside the cloud IDs in `PetCatalog.swift`:

```swift
public static let knotling = PetID(rawValue: "knotling")
public static let prismite = PetID(rawValue: "prismite")
public static let orbitling = PetID(rawValue: "orbitling")
```

- [ ] **Step 4: Add the category descriptor**

Add after `.cloudPets` in `PetDefinition.swift`:

```swift
public static let tesslings = PetCategoryDescriptor(
    id: "tesslings",
    displayName: "Tesslings",
    order: 1
)
```

- [ ] **Step 5: Run the focused test and full current suite**

Run:

```bash
swift test --filter PetCatalogTests.tesslingIdentifiersAndCategoryMetadataAreStable
swift test
```

Expected: both commands pass; the new IDs remain unregistered until their art packs exist.

- [ ] **Step 6: Commit the metadata seam**

```bash
git add Sources/PetsCore/Pets/PetCatalog.swift Sources/PetsCore/Pets/PetDefinition.swift Tests/PetsCoreTests/Pets/PetCatalogTests.swift
git commit -m "feat: add Tessling catalog identifiers"
```

---

### Task 2: Add Knotling definition and production art

**Files:**
- Create: `Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift`
- Create: `Sources/PetsCore/Resources/PetArt/knotling/idle/frame-000.png` through `frame-007.png`
- Create: `Sources/PetsCore/Resources/PetArt/knotling/busy/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/knotling/waiting/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/knotling/excited/frame-000.png` through `frame-004.png`
- Create: `Sources/PetsCore/Resources/PetArt/knotling/sleeping/frame-000.png` through `frame-003.png`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

**Interfaces:**
- Consumes: `PetID.knotling`, `PetCategoryDescriptor.tesslings`, `PetArtPack`, and the existing asset renderer.
- Produces: `KnotlingPetDefinition` and the reusable private `tesslingArtPack(slug:)` helper used by later tasks.

- [ ] **Step 1: Write failing Knotling catalog and resource tests**

Add this exact test to `PetCatalogTests`:

```swift
@Test
func knotlingDefinitionOwnsItsCatalogAndAnimationContract() throws {
    let definition = try #require(PetCatalog.definition(for: .knotling))
    #expect(definition is KnotlingPetDefinition)
    #expect(definition.displayName == "Knotling")
    #expect(definition.rarity == .common)
    #expect(definition.capabilities.maximumPixelation == .chunky)
    guard case let .assetPack(pack) = definition.renderSource else {
        Issue.record("Knotling must use an asset pack")
        return
    }
    #expect(pack.idle.frames.count == 8)
    #expect(pack.busy?.frames.count == 4)
    #expect(pack.waiting?.frames.count == 4)
    #expect(pack.excited?.frames.count == 5)
    #expect(pack.sleeping?.frames.count == 4)
}
```

- [ ] **Step 2: Run the focused tests and verify the red state**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
```

Expected: catalog compilation or assertions fail because `KnotlingPetDefinition` and its resources do not exist.

- [ ] **Step 3: Generate five Knotling contact sheets with the built-in image tool**

Use `docs/assets/tesslings-family-concept.png` as the identity reference and `Sources/PetsCore/Resources/PetArt/cute-cloud/idle/frame-000.png` as style-only reference. Every prompt must include this exact base:

```text
Use case: stylized-concept
Asset type: production animation contact sheet for a macOS desktop pet
Input images: Image 1 is the Knotling identity reference; preserve its continuous coral-and-plum voxel ribbon, front bridge face, tiny paws, bold hollow openings, golden inner seam, proportions, camera, voxel scale, and material. Image 2 is style-only reference for rendering quality and face legibility; do not copy its cloud shape or white palette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every panel, with no gradient, texture, floor, shadow, reflection, or lighting variation.
Style/medium: soft premium 3D voxel/chibi render with small beveled cubes and a restrained matte-satin finish.
Composition/framing: fixed equal-size grid panels; one full-body Knotling per panel; identical camera, scale, canvas position, and lighting; generous padding; each panel is an animation frame and the last returns naturally to the first.
Constraints: do not redesign the face, paws, palette, ribbon thickness, or voxel size; preserve one continuous ribbon and readable hollow openings; no text, labels, panel borders, watermark, props, clothing, clouds, animals, plants, robots, cast shadow, contact shadow, or glow outside the body; never use #00ff00 in the creature.
```

Append these exact state directions in five separate built-in calls:

```text
Idle sheet: exactly eight panels in a 4-by-2 grid. One crossing slowly threads over and under while the body returns to its canonical knot; include a restrained blink in the last three panels.
Busy sheet: exactly four panels in a 2-by-2 grid. The ribbon tightens and cycles quickly through one crossing while keeping the face bridge stable.
Waiting sheet: exactly four panels in a 2-by-2 grid. The knot loosens into a wider attentive opening, pauses, and reforms.
Excited sheet: exactly five panels in a 3-by-2 grid with the sixth panel left empty green. The ribbon rises into tall celebratory loops and snaps back to canonical form.
Sleeping sheet: exactly four panels in a 2-by-2 grid. The body coils into a low compact knot, eyes close, and the golden seam dims before the loop returns.
```

Save the five generated sheets under `tmp/imagegen/tesslings/knotling/` with stable state filenames.

- [ ] **Step 4: Split, remove chroma, and normalize Knotling frames**

Split each verified grid into equal cells with ImageMagick. For the five-frame excited sheet, discard only the intentionally empty sixth cell. Run the installed helper on every occupied cell:

```bash
python /Users/dariana/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py \
  --input tmp/imagegen/tesslings/knotling/idle-cell-00.png \
  --out tmp/imagegen/tesslings/knotling/idle-alpha-00.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

Repeat with explicit numbered cell/output names for every occupied cell. Resize the complete transparent cell, not its trimmed subject, into a 512x512 canvas so relative scale and anchor survive:

```bash
magick tmp/imagegen/tesslings/knotling/idle-alpha-00.png \
  -resize 512x512 \
  -gravity center \
  -background none \
  -extent 512x512 \
  Sources/PetsCore/Resources/PetArt/knotling/idle/frame-000.png
```

Create every remaining frame by changing only the explicit input cell, alpha output, state directory, and numbered production filename in those two commands. Keep `-resize 512x512 -gravity center -background none -extent 512x512` unchanged. Validate transparent corners and visible hollow openings with `sips`, ImageMagick alpha inspection, and direct visual review.

- [ ] **Step 5: Implement the shared animation helpers and Knotling definition**

Create `TesslingPetDefinitions.swift` with:

```swift
import Foundation

public final class KnotlingPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .knotling,
            displayName: "Knotling",
            rarity: .common,
            category: .tesslings,
            capabilities: .tessling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.94,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 78,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(tesslingArtPack(slug: "knotling"))
        )
    }
}

private extension PetCapabilities {
    static let tessling = PetCapabilities(
        maximumPixelation: .chunky,
        supportsStatusMoods: true,
        supportsHoverExcitement: true
    )
}

private func tesslingArtPack(slug: String) -> PetArtPack {
    PetArtPack(
        idle: tesslingAnimation(slug: slug, state: "idle", frameCount: 8, durations: [1.60, 0.50, 0.45, 0.50, 1.20, 0.12, 0.12, 0.12], blends: [0.18, 0.16, 0.16, 0.16, 0.12, 0.04, 0.04, 0.04], motion: .breathe),
        busy: tesslingAnimation(slug: slug, state: "busy", frameCount: 4, durations: [0.22, 0.22, 0.22, 0.22], blends: [0.08, 0.08, 0.08, 0.08], motion: .bob),
        waiting: tesslingAnimation(slug: slug, state: "waiting", frameCount: 4, durations: [0.70, 0.55, 0.55, 0.70], blends: [0.16, 0.16, 0.16, 0.16], motion: .sway),
        excited: tesslingAnimation(slug: slug, state: "excited", frameCount: 5, durations: [0.18, 0.16, 0.16, 0.18, 0.28], blends: [0.06, 0.06, 0.06, 0.06, 0.08], motion: .pulse),
        sleeping: tesslingAnimation(slug: slug, state: "sleeping", frameCount: 4, durations: [1.30, 0.75, 0.75, 1.30], blends: [0.18, 0.18, 0.18, 0.18], motion: .breathe)
    )
}

private func tesslingAnimation(
    slug: String,
    state: String,
    frameCount: Int,
    durations: [TimeInterval],
    blends: [TimeInterval],
    motion: PetMotionPreset
) -> PetAnimation {
    precondition(durations.count == frameCount && blends.count == frameCount)
    let frames = (0..<frameCount).map { index in
        PetAnimationFrame(
            resourceName: String(format: "frame-%03d", index),
            resourceExtension: "png",
            subdirectory: "PetArt/\(slug)/\(state)",
            duration: durations[index],
            blendDuration: blends[index]
        )
    }
    guard let animation = PetAnimation(frames: frames, loopBehavior: .loop, motion: motion) else {
        preconditionFailure("Tessling animation configuration must be valid")
    }
    return animation
}
```

- [ ] **Step 6: Register Knotling and expose the Tesslings category**

Append `KnotlingPetDefinition()` to `PetCatalog.definitions`. Add a second `PetCatalogCategory` whose ID/display name come from `.tesslings` and whose IDs are currently `[.knotling]`.

- [ ] **Step 7: Run Knotling-focused and full tests**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
swift test
```

Expected: all tests pass, all 25 Knotling frames resolve, and the suite remains green.

- [ ] **Step 8: Commit Knotling**

```bash
git add Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift Sources/PetsCore/Pets/PetCatalog.swift Sources/PetsCore/Resources/PetArt/knotling Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: add animated Knotling pet"
```

---

### Task 3: Add Prismite definition and production art

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift`
- Create: `Sources/PetsCore/Resources/PetArt/prismite/idle/frame-000.png` through `frame-007.png`
- Create: `Sources/PetsCore/Resources/PetArt/prismite/busy/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/prismite/waiting/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/prismite/excited/frame-000.png` through `frame-004.png`
- Create: `Sources/PetsCore/Resources/PetArt/prismite/sleeping/frame-000.png` through `frame-003.png`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

**Interfaces:**
- Consumes: `tesslingArtPack(slug:)` and `.tessling` capabilities from Task 2.
- Produces: `PrismitePetDefinition` and 25 validated Prismite frames.

- [ ] **Step 1: Add failing Prismite assertions**

Add this exact test to `PetCatalogTests`:

```swift
@Test
func prismiteDefinitionOwnsItsCatalogAndAnimationContract() throws {
    let definition = try #require(PetCatalog.definition(for: .prismite))
    #expect(definition is PrismitePetDefinition)
    #expect(definition.displayName == "Prismite")
    #expect(definition.rarity == .rare)
    #expect(definition.capabilities.maximumPixelation == .chunky)
    guard case let .assetPack(pack) = definition.renderSource else {
        Issue.record("Prismite must use an asset pack")
        return
    }
    #expect(pack.idle.frames.count == 8)
    #expect(pack.busy?.frames.count == 4)
    #expect(pack.waiting?.frames.count == 4)
    #expect(pack.excited?.frames.count == 5)
    #expect(pack.sleeping?.frames.count == 4)
}
```

- [ ] **Step 2: Verify the focused tests fail**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
```

Expected: failure because Prismite is not registered and its resources are absent.

- [ ] **Step 3: Generate Prismite contact sheets**

Use `docs/assets/tesslings-family-concept.png` as the identity reference and the Cumulus idle frame as style-only reference. Preserve exactly three interlocking pods, one face on the teal top pod, the indigo-left/apricot-right lower pods, two stabilizer nubs, and one golden square core. Every panel must use a perfectly flat solid `#00ff00` background with no gradient, floor, shadow, reflection, border, label, or watermark. Keep identical camera, subject scale, canvas position, voxel size, lighting, face, and palette across panels. Never use `#00ff00` in the creature. Generate these five sheets:

```text
Idle: eight panels, 4-by-2; pods separate a few voxels, hover around the core, and reseat; final panels include a restrained blink.
Busy: four panels, 2-by-2; the lower pods rotate positions around a brighter core while the face pod stays readable.
Waiting: four panels, 2-by-2; the face pod leans forward and the lower pods brace behind it, then return.
Excited: five panels, 3-by-2 with the sixth empty green; all three pods pop outward and reassemble around the core.
Sleeping: four panels, 2-by-2; the three pods close around the dim core and the face pod lowers with closed eyes.
```

- [ ] **Step 4: Split, key, normalize, and inspect the 25 Prismite frames**

After grid splitting, run every occupied cell through `remove_chroma_key.py` with `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. For the first idle cell, normalize with `magick tmp/imagegen/tesslings/prismite/idle-alpha-00.png -resize 512x512 -gravity center -background none -extent 512x512 Sources/PetsCore/Resources/PetArt/prismite/idle/frame-000.png`; repeat by changing the explicit state and frame number. Reject any frame with more or fewer than three pods, more than one face, a hidden core where the state requires it, or a changed palette assignment.

- [ ] **Step 5: Add and register `PrismitePetDefinition`**

```swift
public final class PrismitePetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .prismite,
            displayName: "Prismite",
            rarity: .rare,
            category: .tesslings,
            capabilities: .tessling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.93,
                anchorX: 0,
                anchorY: 1,
                shadowWidth: 84,
                shadowHeight: 12,
                shadowOpacity: 0.16,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(tesslingArtPack(slug: "prismite"))
        )
    }
}
```

Append the definition after Knotling and update the Tesslings category IDs to `[.knotling, .prismite]`.

- [ ] **Step 6: Run focused and full tests, then commit**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift Sources/PetsCore/Pets/PetCatalog.swift Sources/PetsCore/Resources/PetArt/prismite Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: add animated Prismite pet"
```

Expected: all tests pass before the commit.

---

### Task 4: Add Orbitling definition and production art

**Files:**
- Modify: `Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift`
- Create: `Sources/PetsCore/Resources/PetArt/orbitling/idle/frame-000.png` through `frame-007.png`
- Create: `Sources/PetsCore/Resources/PetArt/orbitling/busy/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/orbitling/waiting/frame-000.png` through `frame-003.png`
- Create: `Sources/PetsCore/Resources/PetArt/orbitling/excited/frame-000.png` through `frame-004.png`
- Create: `Sources/PetsCore/Resources/PetArt/orbitling/sleeping/frame-000.png` through `frame-003.png`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

**Interfaces:**
- Consumes: the shared Tessling animation helper and current substantive-alpha bounds logic.
- Produces: `OrbitlingPetDefinition`, 25 validated Orbitling frames, and the final three-pet category order.

- [ ] **Step 1: Add failing Orbitling assertions**

Add this exact test to `PetCatalogTests`:

```swift
@Test
func orbitlingDefinitionCompletesTheTesslingsFamily() throws {
    let definition = try #require(PetCatalog.definition(for: .orbitling))
    #expect(definition is OrbitlingPetDefinition)
    #expect(definition.displayName == "Orbitling")
    #expect(definition.rarity == .legendary)
    #expect(definition.capabilities.maximumPixelation == .chunky)
    let category = try #require(PetCatalog.builtInCategories.first { $0.id == "tesslings" })
    #expect(category.petIDs == [.knotling, .prismite, .orbitling])
    guard case let .assetPack(pack) = definition.renderSource else {
        Issue.record("Orbitling must use an asset pack")
        return
    }
    #expect(pack.idle.frames.count == 8)
    #expect(pack.busy?.frames.count == 4)
    #expect(pack.waiting?.frames.count == 4)
    #expect(pack.excited?.frames.count == 5)
    #expect(pack.sleeping?.frames.count == 4)
}
```

- [ ] **Step 2: Verify the focused tests fail**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
```

Expected: failure because Orbitling is not registered and its resources are absent.

- [ ] **Step 3: Generate Orbitling contact sheets**

Use `docs/assets/tesslings-family-concept.png` as the identity reference and the Cumulus idle frame as style-only reference. Preserve one butter-yellow rounded-cuboid body, one face, exactly three detached motes—two lilac and one berry—with hollow golden centers, and a compact asymmetric orbit. Every panel must use a perfectly flat solid `#00ff00` background with no gradient, floor, shadow, reflection, border, label, watermark, star, planet, or ring. Keep identical camera, subject scale, canvas position, voxel size, lighting, face, and palette across panels. Never use `#00ff00` in the creature. Generate these five sheets:

```text
Idle: eight panels, 4-by-2; three motes follow an uneven relaxed orbit and return to their canonical positions; final panels include a restrained blink.
Busy: four panels, 2-by-2; the three motes tighten into a fast compact circuit without crossing another panel or clipping.
Waiting: four panels, 2-by-2; the three motes pause in a readable ellipsis-like arrangement and resume their asymmetric orbit.
Excited: five panels, 3-by-2 with the sixth empty green; the three motes scatter upward and spiral back to their exact canonical orbit.
Sleeping: four panels, 2-by-2; all three motes dock visibly against the central body, eyes close, and one golden center pulses faintly.
```

- [ ] **Step 4: Split, key, normalize, and inspect the 25 Orbitling frames**

After grid splitting, run every occupied cell through `remove_chroma_key.py` with `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. For the first idle cell, normalize with `magick tmp/imagegen/tesslings/orbitling/idle-alpha-00.png -resize 512x512 -gravity center -background none -extent 512x512 Sources/PetsCore/Resources/PetArt/orbitling/idle/frame-000.png`; repeat by changing the explicit state and frame number. Reject frames that lose a mote, create a fourth mote, clip any mote, move a mote into a neighboring grid cell, change the central body identity, or turn the motif into planetary rings or space imagery.

- [ ] **Step 5: Add and register `OrbitlingPetDefinition`**

```swift
public final class OrbitlingPetDefinition: PetDefinition, @unchecked Sendable {
    public init() {
        super.init(
            id: .orbitling,
            displayName: "Orbitling",
            rarity: .legendary,
            category: .tesslings,
            capabilities: .tessling,
            defaults: .standard,
            presentation: PetPresentationConfiguration(
                contentScale: 0.91,
                anchorX: 0,
                anchorY: 0,
                shadowWidth: 90,
                shadowHeight: 11,
                shadowOpacity: 0.14,
                transitionDuration: 0.16
            ),
            renderSource: .assetPack(tesslingArtPack(slug: "orbitling"))
        )
    }
}
```

Append the definition after Prismite and set the Tesslings category order to `[.knotling, .prismite, .orbitling]`.

- [ ] **Step 6: Run focused and full tests, then commit**

```bash
swift test --filter PetCatalogTests
swift test --filter PetArtResourceTests
swift test
git add Sources/PetsCore/Pets/Definitions/TesslingPetDefinitions.swift Sources/PetsCore/Pets/PetCatalog.swift Sources/PetsCore/Resources/PetArt/orbitling Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: add animated Orbitling pet"
```

Expected: all tests pass before the commit.

---

### Task 5: Harden catalog, collection, and art validation

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetDefinitionTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCollectionStateTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift`

**Interfaces:**
- Consumes: final eight-definition catalog and existing chest/picker behavior.
- Produces: regression coverage for order, rarity pools, collection eligibility, resources, alpha, anchors, and UI discovery.

- [ ] **Step 1: Replace cloud-only catalog expectations with final family expectations**

Require definition and category order:

```swift
#expect(PetCatalog.definitions.map(\.id) == [
    .cuteCloud, .nimbusCloud, .cirrusCloud, .lenticularCloud, .snowCloud,
    .knotling, .prismite, .orbitling,
])
#expect(PetCatalog.builtInCategories.map(\.id) == ["cloud-pets", "tesslings"])
#expect(PetCatalog.builtInCategories[1].petIDs == [.knotling, .prismite, .orbitling])
```

Require final rarity pools:

```swift
#expect(PetCatalog.petIDs(for: .common) == [.cuteCloud, .nimbusCloud, .knotling])
#expect(PetCatalog.petIDs(for: .rare) == [.cirrusCloud, .lenticularCloud, .prismite])
#expect(PetCatalog.petIDs(for: .legendary) == [.snowCloud, .orbitling])
```

- [ ] **Step 2: Add a collection unlock regression test**

Add this exact test to `PetCollectionStateTests`:

```swift
@Test
func tesslingsEnterTheirRarityChestPools() throws {
    var common = PetCollectionState(
        ownedPetIDs: [.cuteCloud, .nimbusCloud],
        keyCount: 1
    )
    #expect(try common.openChest(
        rarity: .common,
        eligiblePetIDs: PetCatalog.builtInPetIDs,
        selectionIndex: 0
    ) == .knotling)
    #expect(common.keyCount == 0)

    var rare = PetCollectionState(
        ownedPetIDs: [.cirrusCloud, .lenticularCloud],
        keyCount: 2
    )
    #expect(try rare.openChest(
        rarity: .rare,
        eligiblePetIDs: PetCatalog.builtInPetIDs,
        selectionIndex: 0
    ) == .prismite)
    #expect(rare.keyCount == 0)

    var legendary = PetCollectionState(
        ownedPetIDs: [.snowCloud],
        keyCount: 4
    )
    #expect(try legendary.openChest(
        rarity: .legendary,
        eligiblePetIDs: PetCatalog.builtInPetIDs,
        selectionIndex: 0
    ) == .orbitling)
    #expect(legendary.keyCount == 0)
}
```

- [ ] **Step 3: Scope the existing eight-idle-frame assertion correctly**

Rename `everyCloudHasExactlyEightIdleFrames` to `everyRegisteredPetHasExactlyEightIdleFrames` and keep its loop over `PetCatalog.definitions`, because all five clouds and all three Tesslings now satisfy the eight-frame idle contract.

- [ ] **Step 4: Add exact Tessling state-count and alpha-bound assertions**

Add this test inside `PetArtResourceTests`, where the existing private `alphaBounds(in:)` helper is available:

```swift
@Test
func tesslingStatePacksHaveExactCountsAndStableBounds() throws {
    for petID in [PetID.knotling, .prismite, .orbitling] {
        let definition = try #require(PetCatalog.definition(for: petID))
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Every Tessling must use an asset pack")
            continue
        }
        let animations = [
            (pack.idle, 8),
            (try #require(pack.busy), 4),
            (try #require(pack.waiting), 4),
            (try #require(pack.excited), 5),
            (try #require(pack.sleeping), 4),
        ]
        for (animation, expectedCount) in animations {
            #expect(animation.frames.count == expectedCount)
            let images = try animation.frames.map { frame -> CGImage in
                let url = try #require(PetArtResourceLocator.url(for: frame))
                let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
                return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            }
            let canonical = try #require(alphaBounds(in: images[0]))
            for image in images {
                let bounds = try #require(alphaBounds(in: image))
                #expect(abs(bounds.midX - canonical.midX) <= 8)
                #expect(abs(bounds.midY - canonical.midY) <= 8)
                if petID == .orbitling {
                    #expect(bounds.minX >= 8)
                    #expect(bounds.minY >= 8)
                    #expect(bounds.maxX <= 504)
                    #expect(bounds.maxY <= 504)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Run all focused suites and the full suite**

```bash
swift test --filter PetCatalogTests
swift test --filter PetDefinitionTests
swift test --filter PetArtResourceTests
swift test --filter PetCollectionStateTests
swift test --filter PetCollectionViewSourceTests
swift test
```

Expected: all commands pass.

- [ ] **Step 6: Commit validation coverage**

```bash
git add Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetDefinitionTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift Tests/PetsCoreTests/Pets/PetCollectionStateTests.swift Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift
git commit -m "test: cover Tessling catalog and artwork"
```

---

### Task 6: Build motion contact sheets and verify the packaged app

**Files:**
- Create: `docs/assets/tesslings/knotling-idle.png`
- Create: `docs/assets/tesslings/prismite-idle.png`
- Create: `docs/assets/tesslings/orbitling-idle.png`
- Modify: `README.md` only if its current pet-family section enumerates available families.

**Interfaces:**
- Consumes: final production frames and `scripts/build_idle_contact_sheet.swift`.
- Produces: reviewable motion sheets and a verified packaged application.

- [ ] **Step 1: Build the three idle contact sheets from production assets**

```bash
mkdir -p docs/assets/tesslings
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/knotling/idle docs/assets/tesslings/knotling-idle.png
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/prismite/idle docs/assets/tesslings/prismite-idle.png
swift scripts/build_idle_contact_sheet.swift Sources/PetsCore/Resources/PetArt/orbitling/idle docs/assets/tesslings/orbitling-idle.png
```

Expected: each output is a 1024x512 two-row sheet showing eight aligned frames.

- [ ] **Step 2: Inspect family distinction and animation continuity**

Confirm Knotling keeps readable openings, Prismite keeps exactly three pods and one core, Orbitling keeps exactly three motes, and no two pets converge on the same silhouette during a loop. Confirm each last frame returns naturally to the first.

- [ ] **Step 3: Run the repository gate**

```bash
./scripts/check.sh
```

Expected: all Swift tests pass and the package builds successfully.

- [ ] **Step 4: Build and verify the app bundle**

```bash
./scripts/run_app.sh --verify
```

Expected: the packaged `Pets.app` launches successfully from the repository's normal bundle path and passes the script's verification checks.

- [ ] **Step 5: Inspect the running UI**

Verify the Tesslings category appears after Cloud Pets in the collection browser; locked/owned behavior remains correct; each pet renders in collection cards, settings previews, and overlay; all five states fit the overlay without clipping; Chunky pixelation remains available; and multiple Tesslings animate with independent phase offsets.

- [ ] **Step 6: Commit review assets and any truthful README update**

```bash
git add docs/assets/tesslings README.md
git commit -m "docs: add Tessling motion previews"
```

If `README.md` does not enumerate pet families, leave it unstaged and commit only `docs/assets/tesslings` with the same message.

- [ ] **Step 7: Confirm the final worktree**

```bash
git status --short
git log -6 --oneline
```

Expected: no tracked implementation changes remain unstaged; only deliberately retained ignored or exploratory image-generation files may remain outside version control.
