# Pet Definition Classes and Generated Art Packs Design

**Date:** 2026-07-11

**Status:** Approved in conversation; pending written-spec review

## Summary

Pets will move from a static catalog plus a monolithic SwiftUI sprite switch to a class-based definition system. Every built-in pet will have one immutable concrete `PetDefinition` subclass that owns its developer-controlled metadata, capabilities, defaults, presentation configuration, and render source.

Persisted user configuration will remain in the existing Codable `PetInstance` value. Definition objects will not be persisted or mutated at runtime. `PetInstance.petID` will resolve through `PetCatalog` to a registered definition, preserving existing pet IDs and saved configurations.

The migration will be incremental. All 17 current pets will enter the new registry immediately, but only Cute Cloud will move to a generated asset pack in the first implementation. The other pets will continue using their existing SwiftUI renderers through a temporary legacy adapter until their artwork is replaced.

## Goals

- Establish one concrete definition class for every built-in pet.
- Centralize pet metadata, category, capabilities, defaults, presentation settings, and rendering configuration.
- Support asset-backed idle, busy, waiting, excited, and sleeping animations.
- Require idle artwork while allowing every other animation to be absent.
- Fall back directly to idle whenever a requested optional animation is absent.
- Preserve all existing `PetID` raw values and persisted `PetInstance` data.
- Support a pet-by-pet migration from legacy SwiftUI artwork to generated raster assets.
- Rebuild Cute Cloud in the supplied soft 3D voxel/chibi art direction as the canonical first pet.
- Use the same rendering path for the overlay, settings preview, carousel, and sprite picker.
- Make invalid or missing built-in assets visible and diagnosable without crashing the app.

## Non-Goals

- User-imported pet packs.
- A public plugin format or pet marketplace.
- A pet editor or animation authoring UI.
- Replacing the other 16 pets' artwork in the first implementation.
- Changing the existing pet IDs, user-facing names, or category ordering.
- Persisting definition classes or generated asset metadata in `UserDefaults`.
- Adding new user-facing settings solely for the new renderer.

## Current State

The repository currently has 17 built-in pet IDs. `PetCatalog` stores parallel metadata and category lists, while `PetSprite` selects one of several renderer families through `PetRenderFamily`. Nearly all sprite drawing and animation behavior lives in `Sources/Pets/PetSprites.swift`.

`PetInstance` is already the correct persistence boundary. It stores the selected `PetID`, custom name, visibility, overlay position, pixelation, session context, and animation toggles. It round-trips through JSON in `UserDefaults` and must remain a value type.

The existing overlay passes a session status and hover state into `PetSprite`. The settings and picker also render through `PetSprite`, so changing that boundary once can update every pet preview surface consistently.

## Core Architecture

### Definition Classes

`PetDefinition` will be an immutable base class in `PetsCore`. It represents one built-in species or visual identity, not one user-created instance.

It owns:

- `id: PetID`
- `displayName: String`
- `category: PetCategoryDescriptor`
- `capabilities: PetCapabilities`
- `defaults: PetDefaultConfiguration`
- `presentation: PetPresentationConfiguration`
- `renderSource: PetRenderSource`

Each existing built-in ID will have one final concrete subclass, such as `CuteCloudPetDefinition`, `CodeBotPetDefinition`, and `VoxelDragonPetDefinition`. `PetCatalog` will hold one shared immutable instance of every subclass.

The subclasses may override specialized behavior later, but the first implementation should prefer constructor configuration and small, testable value objects over unnecessary overrides.

Definition objects must be safe to share. Their properties are immutable after initialization, and they must not contain UI state, animation timers, decoded images, or user configuration.

### Persisted Instances

`PetInstance` remains a Codable struct and continues to own user-controlled values:

- UUID
- Custom name
- Selected `PetID`
- Pixelation
- Session context line count
- Animation settings
- Visibility
- Overlay position

No definition class or asset-pack object will be encoded. Existing saved instances continue resolving through the same `PetID` raw values.

The catalog definition supplies defaults and capability limits. `PetInstance` supplies overrides. For example, a definition supplies maximum pixelation, while an instance stores the user's chosen pixelation after catalog clamping.

### Registry

`PetCatalog` becomes the single registry of `[PetDefinition]`. It validates unique IDs and derives lookup maps, built-in ordering, and category membership from that list.

The registry replaces duplicated entry and category arrays. Existing convenience APIs may remain during migration, but they must delegate to definitions rather than maintaining a second source of truth:

- `displayName(for:)`
- `category(for:)`
- `maximumPixelation(for:)`
- `definition(for:)`
- `builtInPetIDs`
- `builtInCategories`

Category ordering remains:

1. Cloud Pets
2. Workspace Pets
3. Nature Pets
4. Cozy Pets
5. Voxel Pets

Pet ordering inside each category remains unchanged.

Duplicate definition IDs are a programmer error. Registry construction will detect them deterministically, and tests will verify the complete built-in set and order.

## Rendering Model

### Render Source

Every definition has one `PetRenderSource`:

```swift
public enum PetRenderSource: Sendable {
    case assetPack(PetArtPack)
    case legacy(PetRenderFamily)
}
```

Cute Cloud will use `.assetPack`. The remaining 16 pets will use `.legacy` in the first implementation.

`PetRenderFamily` is transitional. It remains only to route unmigrated definitions to the existing SwiftUI implementations. It can be removed after the last pet has an asset pack.

### Shared Visual Context

The overlay, picker, and settings preview will construct a `PetVisualContext` and pass it to `PetSprite` with the instance configuration. The context contains the raw information needed to select an animation:

- Dominant session status
- Whether any visible session is active
- Whether the pet is hovered
- The instance animation settings

The overlay must stop converting disabled moods into `.unknown` before rendering. The resolver needs both the real status and the settings to distinguish “moods disabled” from “no active session.”

Legacy renderers receive an adapter that reproduces their current `status` and `isExcited` inputs. Asset-backed renderers receive the resolved visual state and animation settings.

### State Resolution

`PetVisualState` has five values:

```swift
public enum PetVisualState: String, CaseIterable, Sendable {
    case idle
    case busy
    case waiting
    case excited
    case sleeping
}
```

State priority is:

1. Hovered with hover excitement enabled requests `excited`.
2. With status moods disabled, request `idle`.
3. A waiting session requests `waiting`.
4. A busy session requests `busy`.
5. An active idle session requests `idle`.
6. No active session requests `sleeping`.

After the state is selected, the art pack resolves it. If that optional state is absent, it falls back directly to idle. It does not fall through to another optional state.

Examples:

- Hovered busy pet without excited artwork -> idle.
- Waiting pet without waiting artwork -> idle.
- No active session without sleeping artwork -> idle.
- Moods disabled -> idle even when the session is busy.

## Art and Animation Model

### Art Pack

`PetArtPack` is an immutable value owned by a definition. Its shape enforces a required idle animation and optional alternate states:

```swift
public struct PetArtPack: Sendable {
    public let idle: PetAnimation
    public let busy: PetAnimation?
    public let waiting: PetAnimation?
    public let excited: PetAnimation?
    public let sleeping: PetAnimation?
}
```

An optional state is represented by `nil`, not an empty animation. `PetAnimation` requires at least one frame. An empty frame array is invalid configuration.

### Animation

`PetAnimation` owns:

- One or more `PetAnimationFrame` values.
- Per-frame duration.
- Loop behavior.
- Crossfade duration when entering the animation.
- Optional code-driven motion preset.

One-frame animations are valid. They can still appear alive through a restrained motion preset such as breathing, bobbing, swaying, or pulsing. Multi-frame animations use frame timing in addition to the optional motion preset.

When animation is disabled by the instance:

- The renderer displays the first frame.
- Code-driven motion stops.
- The selected state remains correct unless status moods are disabled.

Animation timelines live in the SwiftUI renderer. They are not stored in definition objects or `PetInstance`.

### Presentation Configuration

`PetPresentationConfiguration` keeps per-pet visual alignment out of shared UI code. It owns:

- Logical canvas size.
- Content scale.
- X/Y anchor adjustment.
- Shadow size and opacity.
- Default transition duration.

The overlay continues to provide the containing frame. The definition controls how its artwork sits inside that frame, so differently shaped pets can share the same overlay and picker components without hard-coded ID checks.

Shadows and status glows are runtime layers. They are not baked into generated PNGs. This keeps alpha extraction clean and gives every surface consistent grounding.

## Resource Layout

Built-in artwork will be packaged as SwiftPM resources under `PetsCore` so definitions and tests share one resource boundary:

```text
Sources/PetsCore/Resources/PetArt/cute-cloud/
├── idle/frame-000.png
├── busy/frame-000.png
├── waiting/frame-000.png
├── excited/frame-000.png
└── sleeping/frame-000.png
```

Every production frame must:

- Be a 512x512 PNG.
- Have an alpha channel.
- Have transparent corners.
- Use the same camera angle and canvas origin as the other states for that pet.
- Use consistent subject scale and floor anchor.
- Contain no baked background, floor, text, watermark, glow, or cast shadow.

The design supports multiple numbered frames in any state directory without changing the renderer API.

Resource resolution happens through a small `PetsCore` locator that knows its own `Bundle.module`. The SwiftUI renderer loads the resolved URL into an image. Resource paths are developer-authored constants inside the definition, not persisted strings.

## Cute Cloud Art Direction

Cute Cloud is the canonical first migrated pet. The supplied image is a style and identity reference, not an edit target.

The required visual language is:

- Rounded chibi cloud silhouette assembled from small, softly beveled voxels.
- Near-isometric three-quarter view with readable 3D depth.
- Warm cream studio lighting and restrained pastel shading.
- Glossy black square eyes with small white highlights.
- Tiny centered mouth and subtle pink blush.
- Short rounded voxel arms.
- Soft, friendly proportions with the face remaining readable at overlay size.

The generated state images must preserve the same character identity, camera angle, material, voxel scale, lighting direction, proportions, and canvas placement. State changes should come from expression and pose rather than redesigning the character.

### Generation Workflow

The built-in image generation path will be used, with the supplied image included as a style/identity reference.

1. Generate a canonical neutral Cute Cloud on a perfectly flat chroma-key background.
2. Validate identity, silhouette, camera, voxel size, padding, and small-size readability.
3. Use the approved canonical result as an additional reference for each state.
4. Generate idle, busy, waiting, excited, and sleeping visuals with identity invariants repeated in every prompt.
5. Remove the chroma key locally with soft matte and despill processing.
6. Normalize each result onto a 512x512 transparent canvas with a shared anchor.
7. Validate alpha, corners, subject bounds, color contamination, and edge quality.
8. Build a side-by-side contact sheet for final visual comparison.
9. Keep only accepted project assets under `Sources/PetsCore/Resources/PetArt/cute-cloud/`.

The generated source must have no cast shadow because shadows are supplied by the runtime. If chroma-key removal cannot preserve the voxel edges cleanly, the implementation must pause before switching to a model-native transparency fallback.

## UI Integration

`PetSprite` remains the single rendering entry point used by:

- The desktop overlay.
- The settings sprite summary.
- The pet carousel.
- The sprite picker.

`PetSprite` resolves the definition once and branches by `PetRenderSource`:

- Asset pack -> `AssetPetSprite`.
- Legacy family -> `LegacyPetSpriteAdapter`.

`AssetPetSprite` owns frame playback, state transitions, and definition-supplied motion. Migrated pets must not also receive the current outer hover bounce and offset, which would duplicate animation. The legacy adapter continues receiving the existing behavior until those pets migrate.

The UI should derive capability labels from the definition. It must not advertise “Moods” or another animation capability when the definition does not support it.

No settings-window layout change is required for this phase.

## Error Handling

Optional missing animations are normal and silently resolve to idle.

A referenced frame that cannot be loaded is a developer configuration error. The loader should record a concise diagnostic and attempt the idle animation. If idle itself cannot be loaded, the renderer shows a visible development placeholder containing the pet ID rather than crashing or rendering an invisible pet.

Invalid resource configuration is covered by tests:

- Duplicate pet ID.
- Missing idle animation.
- Empty animation frame list.
- Missing resource file.
- Incorrect dimensions.
- Missing alpha channel.
- Non-transparent corners.

Runtime image decoding should be cached by resource URL. The immutable definition registry must not become an image cache or own mutable UI state.

## Migration

The first implementation performs these migrations together:

1. Introduce the definition, capabilities, defaults, presentation, art-pack, animation, state, and render-source types.
2. Add concrete definition classes for all 17 current built-in pets.
3. Replace `PetCatalog.entries` and hand-maintained category membership with the definition registry.
4. Preserve the existing public catalog helpers by delegating to definitions.
5. Add the visual-context and state-resolution path.
6. Add the asset renderer and legacy adapter.
7. Generate, validate, package, and register the Cute Cloud art pack.
8. Keep all other definitions on their current legacy render families.

No persistence migration is needed because existing raw `PetID` values remain unchanged. The current classic-cloud compatibility mapping also remains in place.

Future pet migrations replace only that definition's `.legacy` render source with `.assetPack` and add its validated resource directory. They must not require catalog, picker, overlay, or persistence changes.

## Testing

### Core Unit Tests

- Every current raw `PetID` resolves to one definition.
- Definition IDs are unique.
- Built-in and category order exactly match the current catalog.
- Names and maximum pixelation values remain unchanged.
- The registry derives categories without duplicate membership.
- `PetInstance` JSON round-trip remains unchanged.
- Existing legacy ID normalization remains unchanged.
- Every optional visual state resolves to itself when present.
- Every absent optional state resolves directly to idle.
- Hover, mood settings, status, and session availability follow the approved priority.
- A one-frame animation is valid.
- An empty animation is rejected.

### Resource Validation Tests

- Every referenced resource exists.
- Every accepted frame is 512x512.
- Every accepted frame has alpha.
- All four corners are transparent.
- Subject bounds remain within the safe canvas margin.
- State frames for one pet remain within the allowed anchor and scale tolerance.

### Renderer Tests

- Asset and legacy sources select the correct renderer.
- One-frame animations render without a timer-dependent failure.
- Multi-frame animations advance using configured durations and loop behavior.
- Disabling animation freezes the first frame and motion.
- State changes use the configured transition.
- A missing optional animation renders idle.
- A missing idle resource renders the diagnostic placeholder.
- Picker and overlay both use `PetSprite` and therefore the same definition path.

### Verification

- Run focused catalog, definition, state resolver, resource, and renderer tests.
- Run `./scripts/check.sh`.
- Build and relaunch the packaged `.app`.
- Inspect Cute Cloud in the overlay, settings summary, carousel, and picker.
- Inspect idle, busy, waiting, excited, and sleeping states.
- Confirm the other 16 pets still render through their legacy paths.
- Compare the final Cute Cloud state contact sheet for identity and anchor consistency.

## Acceptance Criteria

- All 17 current pets are represented by concrete immutable definition classes.
- `PetCatalog` uses those definitions as its only metadata and category source.
- Existing saved `PetInstance` values continue to decode and render.
- Cute Cloud renders from validated generated assets in the approved art direction.
- Cute Cloud supports idle, busy, waiting, excited, and sleeping artwork in the first pack.
- Optional-state infrastructure allows future pets to omit any non-idle state.
- Missing optional states fall back directly to idle.
- The other 16 pets remain available and visually unchanged during the first migration.
- Overlay, settings preview, carousel, and picker share the same rendering entry point.
- The full test/build check passes and the rebuilt app is visually verified.
