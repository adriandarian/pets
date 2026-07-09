# Voxel Pets Design

## Goal

Pets should add a small built-in voxel pet family that feels distinct from the existing cloud, workspace, nature, and cozy pets while using the same catalog, settings, overlay, and persistence paths.

This feature should:

- Add a new `Voxel Pets` category to the built-in pet catalog.
- Include three built-in voxel pets: `Voxel Cat`, `Voxel Slime`, and `Voxel Dragon`.
- Render each voxel pet with SwiftUI primitives, not external art files.
- Support the existing pixelation controls, status moods, hover bounce, picker previews, carousel previews, and overlay rendering.
- Avoid changing the settings window structure or the pet instance persistence format.

## Current Context

Pets is a Swift Package with:

- `PetsCore`, which owns `PetID`, `PetCatalog`, `PetInstance`, pixelation options, and catalog tests.
- `Pets`, which owns SwiftUI rendering for the overlay, settings window, sprite picker, and pet previews.

The current working tree already has an expanded catalog and several SwiftUI-drawn pet families:

- `cloud-pets`
- `workspace-pets`
- `nature-pets`
- `cozy-pets`

`PetSprite` routes non-cloud categories to family-specific SwiftUI renderers based on `PetCatalog.category(for:)?.id`. The voxel family should follow that pattern.

## Recommended Approach

Build voxel pets as a new built-in SwiftUI sprite family.

Add three IDs to `PetID`:

- `voxelCat`
- `voxelSlime`
- `voxelDragon`

Add one catalog category:

```swift
PetCatalogCategory(
    id: "voxel-pets",
    displayName: "Voxel Pets",
    petIDs: [
        .voxelCat,
        .voxelSlime,
        .voxelDragon
    ]
)
```

Each pet should use hard-edged square or cuboid components with subtle top and side shading:

- `Voxel Cat`: cube head, block ears, compact body, small tail, status-colored eyes.
- `Voxel Slime`: stacked rounded blocks or cubes, translucent green/teal body, status-colored eyes and inner glow.
- `Voxel Dragon`: blocky snout, horns, wings, tail, warm body color, status-colored eyes.

This is preferred because it keeps the feature lightweight, testable, and consistent with the current code-native sprite system. It also avoids asset packaging and Retina scaling issues.

## Alternatives Considered

### External PNG Sprite Assets

Voxel pets could be added as generated PNG sprites or sprite sheets.

This might allow richer texture detail, but it introduces asset storage, transparency/cropping checks, resolution decisions, and separate image loading behavior. It is unnecessary for the first voxel family.

### Procedural Block Map Renderer

The app could define each pet from a reusable grid or pseudo-isometric block map.

This would be useful if Pets planned to support dozens of voxel pets or user-authored voxel pets, but it is more abstraction than three built-in sprites need. A small set of reusable SwiftUI block helpers is enough.

## Architecture

### Catalog

`PetCatalog` should expose the voxel pets like every other built-in category:

- `builtInCategories` includes `Voxel Pets`.
- `builtInPetIDs` automatically includes the new IDs.
- `displayName(for:)` returns the three user-facing names.
- `maximumPixelation(for:)` allows `.chunky` for each voxel pet.

No persistence migration is required because pet instances store `PetID` raw values and the new IDs are additive.

### Rendering

`PetSprite` should route `"voxel-pets"` to a new private SwiftUI renderer:

```swift
VoxelPetSprite(petID: petID, status: status, isExcited: isExcited)
```

The renderer should:

- Use `GeometryReader` with the same 128-unit coordinate system used by existing families.
- Draw an existing `petShadow(unit:)`.
- Offset the sprite slightly upward when `isExcited` is true.
- Reuse `statusColor(_:)` for eyes or glow so status moods stay consistent.
- Use reusable helpers for block faces, square eyes, and highlights.

The voxel family should remain code-native and should not add new image files.

### Settings and Picker

No settings layout changes are required.

The existing picker and carousel read from `PetCatalog.builtInCategories` and render previews through `PetSprite`, so the new category should appear automatically once the catalog and renderer are updated.

### Tests

Unit tests should cover:

- The catalog contains a category with `id == "voxel-pets"` and `displayName == "Voxel Pets"`.
- The voxel category contains `.voxelCat`, `.voxelSlime`, and `.voxelDragon` in that order.
- `displayName(for:)` returns `Voxel Cat`, `Voxel Slime`, and `Voxel Dragon`.
- `maximumPixelation(for:)` returns `.chunky` for all voxel pets.
- A `PetInstance` using a voxel pet preserves `.chunky` pixelation.

Manual verification should cover:

- Sprite picker shows the `Voxel Pets` category.
- Each voxel pet preview renders in the picker and carousel.
- Selecting each voxel pet updates the overlay.
- Pixelation segmented control allows `Chunky`.
- Status moods tint eyes/glow for idle, busy, waiting, and unknown states.
- Hover bounce still moves the sprite without clipping.

## Error Handling

No new error surface is expected.

If an unknown pet ID enters `PetSprite`, the existing fallback behavior should remain unchanged. Voxel pets are built-in IDs and should not require special decode or migration handling.

## Out of Scope

- User-imported voxel art.
- Sprite sheets or animation-frame assets.
- A general voxel editor.
- Per-pet custom colors.
- Changing the Settings window layout.
- Changing the pet instance persistence schema.
