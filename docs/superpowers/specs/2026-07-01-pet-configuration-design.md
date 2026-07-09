# Pets Configuration Design

## Goal

Pets should move from a Claude-specific single-pet utility toward a configurable desktop pet system.

This first step should:

- Keep the menu bar menu short and action-oriented.
- Move detailed preferences into a fully fledged Settings window.
- Add a pet customization surface that can support different pet sprites and behaviors.
- Allow multiple pets to be spawned and configured independently.

## Current Context

Pets is a Swift Package with:

- `PetsCore`, which owns pet catalog types, sprite pixelation, session context line count, and Claude session scanning.
- `Pets`, which owns the menu bar extra, settings scene, AppKit overlay panel, and SwiftUI overlay views.

The current menu bar menu includes both commands and detailed preferences:

- Open at Login
- Respawn Pet
- Hide Pet
- Sprite selection
- Pixelation selection
- Context line slider
- Configure Pets
- Quit Pets

The current app has one `NSPanel`, one shared `PetStore`, and one selected pet configuration. Multiple pets will require the overlay/window layer and store state to move from one global pet to a list of pet instances.

## Visual Direction

### Menu Bar Menu

The menu bar menu should only expose the four top-level commands requested by the user:

```text
Pets
┌──────────────────────────┐
│ ↻  Respawn Pet           │
│ ◐  Hide Pet              │
│ ⚙  Configure...          │
│ ──────────────────────── │
│ ⏻  Quit Pets       │
└──────────────────────────┘
```

`Hide Pet` should become `Show Pet` when all pets are hidden. Menu-level `Respawn Pet` should respawn all visible pets. Selected-pet actions belong in Settings.

### Settings Window

Settings should be a native macOS settings scene, not a custom full-screen app window. A sidebar or tab layout is acceptable; the first implementation should choose the simplest native SwiftUI structure that stays readable at desktop settings-window size.

```text
┌──────────────────────────────────────────────────────────────┐
│ Pets Settings                                          │
├───────────────┬──────────────────────────────────────────────┤
│ General       │ Pets                                         │
│ Pets          │ ┌────────────────────┐ ┌───────────────────┐ │
│ Sessions      │ │ Active Pets        │ │ Pet Details       │ │
│ Appearance    │ │                    │ │                   │ │
│ Advanced      │ │ + Add Pet          │ │ Name              │ │
│               │ │                    │ │ [Claude Cloud   ] │ │
│               │ │ ✓ Claude Cloud     │ │                   │ │
│               │ │   Classic Claude   │ │ Pet Sprite        │ │
│               │ │   Helper Cloud     │ │ [Cute Cloud   v]  │ │
│               │ │                    │ │                   │ │
│               │ │ Respawn Selected   │ │ Pixelation        │ │
│               │ │ Hide Selected      │ │ Smooth ○ ○ ● ○    │ │
│               │ └────────────────────┘ │                   │ │
│               │                        │ Context Lines     │ │
│               │                        │ [---●----] 2      │ │
│               │                        │                   │ │
│               │                        │ Animations        │ │
│               │                        │ Hover bounce  [✓] │ │
│               │                        │ Idle motion   [✓] │ │
│               │                        │ Status moods  [✓] │ │
│               │                        └───────────────────┘ │
└───────────────┴──────────────────────────────────────────────┘
```

## Recommended Approach

Build a settings-first configuration model with independent pet instances.

Each spawned pet should have its own configuration:

- Stable pet instance ID.
- Display name.
- Selected sprite or pet type.
- Pixelation setting, clamped by the selected sprite's capabilities.
- Session context line count.
- Animation toggles.
- Visibility state.
- Overlay position metadata: last panel origin and horizontal placement.

Global settings should stay separate:

- Open at Login.
- Default configuration for newly added pets.
- App-level Claude session behavior remains unchanged in this design.

This is preferred because multiple pets are only useful if users can make them different. Shared-only customization would allow duplicate overlays but would not create meaningful pet variety.

## Alternatives Considered

### Shared Global Pet Settings

All pets could share the same sprite, pixelation, context lines, and animation settings.

This is simpler, but it weakens the multiple-pet feature. It also makes future non-Claude pet expansion harder because the app would still behave like one global pet copied multiple times.

### Keep Detailed Controls in the Menu

The app could keep sprite, pixelation, and context controls in the menu and add only multiple-pet management to Settings.

This preserves quick access, but the current menu is already too crowded. More pet types, animation controls, and per-pet settings would make the menu harder to scan and would not scale.

### Separate Pet Manager Window

Instead of Settings, Pets could open a custom "Pet Manager" window.

This would give more layout freedom, but it fights the user's request for configuration setup and duplicates native macOS settings behavior. A dedicated Settings scene is the better first step.

## Architecture

### Store Model

Replace the single selected-pet state with a pet instance collection.

Suggested core model:

```swift
struct PetInstance: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var petID: PetID
    var pixelation: PetSpritePixelation
    var sessionContextLineCount: Int
    var animationSettings: PetAnimationSettings
    var isVisible: Bool
}

struct PetAnimationSettings: Equatable, Sendable {
    var isHoverBounceEnabled: Bool
    var isIdleMotionEnabled: Bool
    var areStatusMoodsEnabled: Bool
}
```

`PetStore` should publish:

- `petInstances`
- `selectedPetInstanceID`
- app-level values such as `isOpenAtLoginEnabled`, sessions, errors, and last refresh time

The current single-pet values can become computed accessors for the selected instance during migration, but the implementation should avoid keeping two sources of truth.

### Persistence

Persist pet instances as structured data in `UserDefaults`, encoded as JSON. This is enough for a small local settings model and avoids introducing a file format or database.

Migration behavior:

- If no instance collection exists, create one instance from the current `selectedPetID`, `spritePixelation`, and `sessionContextLineCount` defaults.
- Preserve the current built-in default behavior when no prior settings exist.
- Clamp pixelation and context line values through the existing catalog/range helpers.

### Overlay Panels

Move from one `NSPanel?` to a dictionary keyed by pet instance ID:

```swift
private var panels: [PetInstance.ID: PetPanel]
```

Each panel hosts a `PetOverlayView` bound to one pet instance. The overlay should still read shared Claude session data from the store, but render pet-specific customization from its assigned instance.

`Respawn Pet` from the menu should recreate all visible panels. Settings should offer selected-pet controls such as `Respawn Selected` and `Hide Selected`.

### Settings Views

Split settings into focused views rather than growing `PetsApp.swift`:

- `PetSettingsView`: root settings layout.
- `GeneralSettingsPane`: Open at Login and launch behavior.
- `PetConfigurationPane`: active pet list and selected pet details.
- `PetInstanceListView`: add, select, hide, respawn, and remove pets.
- `PetInstanceDetailView`: name, sprite, pixelation, context lines, and animation controls.

The menu bar view should stay small and only own menu commands.

## Data Flow

1. The menu bar `Configure...` item opens the Settings scene.
2. Settings reads and mutates `PetStore`.
3. Store changes update persisted defaults.
4. AppDelegate observes pet instance visibility and creates, closes, or respawns panels.
5. Each panel renders `PetOverlayView` for one pet instance.
6. Claude session scanning remains app-global and is shared by all pets.

## Error Handling

Settings mutations should be clamped and validated immediately:

- Pixelation options unsupported by a selected sprite should be disabled or automatically reduced to the sprite maximum.
- Context lines should remain within `PetSessionContextLineCount.supportedRange`.
- Removing the last pet should either be blocked or immediately create a replacement default pet. The first implementation should block removing the final pet to avoid an empty app state.
- Persistence decode failure should fall back to one default pet and record a visible error.

## Testing

Unit tests should cover:

- Migration from old single-pet defaults to one pet instance.
- Encoding and decoding multiple pet instances.
- Pixelation clamping per pet instance.
- Context line clamping per pet instance.
- Preventing removal of the final pet.

Manual verification should cover:

- Menu shows only Respawn, Hide/Show, Configure, and Quit.
- Settings opens from the menu.
- Changing one pet's sprite/pixelation/context lines does not mutate another pet.
- Adding a second pet creates another visible overlay.
- Hiding, showing, and respawning pets works without losing settings.
- Relaunch restores configured pets.

## Out of Scope

- Importing arbitrary custom pet art files.
- Non-Claude session providers.
- Per-pet assignment to different Claude sessions.
- Drag-and-drop pet ordering.
- Cloud sync.
- A custom main app window separate from Settings.
