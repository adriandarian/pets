# Native Adaptive Pet Settings Design

## Summary

Redesign the Pets settings page as a native macOS sidebar-and-detail interface that automatically follows the user's Light or Dark system appearance. Preserve the existing pet model, commands, persistence, sprite picker, and General tab while replacing the custom green dashboard treatment.

## Goals

- Follow the current macOS appearance without an app-specific theme setting.
- Present pet selection as a native source list that scales to multiple pets.
- Present the selected pet in a calm, scannable detail pane using standard macOS controls.
- Preserve add, select, respawn, show/hide, duplicate, delete, rename, sprite selection, pixelation, context-line, and animation behavior.
- Keep the existing General and Pets settings tabs.

## Non-goals

- Do not change pet persistence or migration.
- Do not change menu-bar commands or overlay behavior.
- Do not add a manual Light/Dark preference.
- Do not redesign the sprite picker sheet beyond removing dependencies on the retired custom palette where required for appearance adaptation.
- Do not change the supported pet catalog, pixelation choices, or context-line range.

## Current Problem

`PetSettingsView` applies `.preferredColorScheme(.dark)`, forcing Dark Mode for the whole settings scene. `PetConfigurationPane` and its child views also use `SettingsDesignPalette`, a fixed green palette with fixed light foreground overlays and a custom pink-to-teal switch. Those choices prevent the page from matching the user's system appearance and make the page read as a web dashboard rather than a Mac settings surface.

## Approved Layout

### Settings shell

Keep the existing `TabView` with General and Pets tabs. Remove the forced color scheme and custom root tint so AppKit and SwiftUI resolve the active appearance and accent color from macOS.

### Pets sidebar

The Pets tab uses `NavigationSplitView`.

- The sidebar contains a `List(selection:)` styled as `.sidebar`.
- A `My Pets` section lists every `PetInstance`.
- Each row shows one sprite thumbnail, the pet name, and `Visible` or `Hidden` as secondary text.
- Native source-list selection replaces the horizontal carousel, custom selected card, overflow calculation, and decorative arrow affordances.
- A bottom bar contains a compact `Add Pet` button.
- Selection writes through to `PetStore.selectPetInstance(_:)` and uses `selectedPetInstanceID` as the source of truth.

### Pet detail

The detail pane is scrollable and keeps one stable layout for every selected pet.

1. A compact header shows the pet name and the secondary summary `<family> · <visibility> · Session aware`.
2. Header actions include a prominent `Respawn`, a standard `Show` or `Hide`, and an ellipsis menu containing `Duplicate` and destructive `Delete`.
3. A large sprite preview keeps the existing grid and live `PetVisualContext`, but uses adaptive system fills and separators.
4. `Pet Details` contains the name field, pixelation segmented control, and bounded context slider.
5. `Appearance` shows the current sprite identity and a `Change Sprite…` button.
6. `Behavior` uses standard macOS switch toggles for Hover bounce, Idle motion, and Status moods.

When no pets exist, keep an empty state in the detail pane with `No Pets`, explanatory text, and a prominent `Add Pet` button. The sidebar remains visible.

## Adaptive Appearance

- Remove `.preferredColorScheme(.dark)`.
- Remove `SettingsDesignPalette` and every fixed red/green/blue settings color.
- Use semantic foreground styles such as `.primary`, `.secondary`, and `.tertiary`.
- Let the split view and sidebar use native system backgrounds.
- Use system materials or dynamic AppKit colors only for contained preview surfaces.
- Use `Color(nsColor: .separatorColor)` for the preview grid at low opacity so it remains visible in both appearances.
- Use the default control tint and default macOS switch style.
- Do not add a theme toggle; macOS appearance changes should propagate automatically.

## Components

- `PetSettingsView`: retains the tab shell and adaptive sizing.
- `PetConfigurationPane`: owns split-view composition, sheets, and delete confirmation.
- `PetSidebar`: binds source-list selection to `PetStore` and owns Add Pet.
- `PetSidebarRow`: renders a lightweight native pet row.
- `PetDetailPane`: composes header, preview, and settings sections.
- `PetPreview`: renders the current pet on an adaptive preview surface.
- `PetDetailsSection`, `PetAppearanceSection`, and `PetBehaviorSection`: own focused control groups using existing bindings.
- `SpritePickerSheet` and `SpritePickerCard`: keep existing catalog behavior while using semantic colors.

## Data Flow

`PetStore` remains the single source of truth. The sidebar reads `petInstances` and `selectedPetInstanceID`; selection calls `selectPetInstance(_:)`. Detail controls use the existing bindings and update methods. Add, duplicate, delete, visibility, respawn, and sprite selection keep their existing store or app-delegate boundaries. No new persisted state is introduced.

## Error and Destructive Behavior

- Keep the existing delete confirmation dialog and explanatory message.
- Keep the existing sprite picker cancel path.
- Keep the current store fallback behavior when persisted pet configuration is invalid.
- Do not hide destructive actions behind gestures; Delete remains labeled inside the ellipsis menu and requires confirmation.

## Accessibility and Desktop Conventions

- All icon-only controls receive help text or accessibility labels.
- Source-list rows remain keyboard-selectable through native `List(selection:)` behavior.
- Buttons and toggles use standard macOS control styles and focus behavior.
- Text uses semantic styles and Dynamic Type-compatible system fonts.
- The detail pane scrolls when the window is shorter than its content.

## Verification

1. Add source-level regression assertions proving the settings file has no forced color scheme or retired palette.
2. Add source-level assertions for `NavigationSplitView`, native sidebar `List(selection:)`, semantic separator color, standard switches, and the compact action menu.
3. Update the old carousel regression assertions to require the new sidebar and reject carousel-only components.
4. Run the focused `PetOverlayTransparencyTests` suite and then `./scripts/check.sh`.
5. Build and launch the packaged app with `./scripts/run_app.sh --verify`.
6. Inspect the running settings page in the machine's current appearance and verify source evidence for automatic appearance inheritance.

## Acceptance Criteria

- The Pets page matches the approved native sidebar/detail visual direction.
- The settings scene contains no forced Light or Dark appearance.
- The settings UI contains no hard-coded custom color palette.
- Light and Dark system appearances resolve appropriate backgrounds, text, separators, controls, and accent color automatically.
- Every existing Pets setting and action remains available.
- Empty and multi-pet collections remain usable.
- Focused tests, the full repository check, build, and packaged-app launch all pass.
