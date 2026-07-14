# Sidebar Inline Rename Design

## Goal

Add a **Rename** action to each pet's sidebar context menu. Choosing it edits the clicked pet's name directly in that row without affecting another pet.

## Considered Approaches

1. **Inline row editing (selected):** matches native macOS source-list behavior and keeps the action spatially tied to the pet.
2. **Rename dialog:** simpler focus handling, but interrupts a small edit with a modal surface.
3. **Select the pet and focus the detail-pane name field:** reuses the existing field, but makes the context action feel indirect and dependent on another pane.

## Interaction

- Add **Rename** at the top of the existing pet-row context menu.
- Choosing Rename selects the clicked pet, replaces only that row's name label with a focused text field, and selects the current name for quick replacement.
- Return commits the draft.
- Moving focus away commits the draft.
- Escape cancels and restores the original name.
- An empty or whitespace-only committed name uses the pet species display name, matching the existing detail-pane behavior.

## State and Persistence

`PetSidebar` owns the transient renamed-pet ID and draft name because only one sidebar row can be edited at a time. `PetSidebarRow` owns field focus and reports commit or cancel through closures.

`PetStore` gains an ID-targeted name update method. The existing selected-pet update delegates to it so the detail pane and context menu share trimming, fallback-name, and persistence behavior.

## Verification

- Add a source regression proving Rename is present, the row becomes an inline text field, Return and Escape are handled, and the clicked pet ID is passed to the store.
- Run the focused regression, the complete Swift test suite, and the app build.
- Relaunch the packaged `dist/Pets.app` bundle.
