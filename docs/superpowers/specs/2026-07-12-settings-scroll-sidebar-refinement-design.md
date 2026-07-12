# Settings Scroll and Sidebar Refinement Design

## Summary

Refine the approved native Pets settings layout so the detail pane remains vertically scrollable without displaying a scrollbar, and the source-list sidebar is the flush left pane of the Settings content area without a containing outline.

## Approved Behavior

- Trackpad, mouse-wheel, keyboard, and accessibility scrolling continue to work in the pet detail pane.
- The vertical scroll indicator is never drawn in the detail pane.
- The sidebar uses the native `NavigationSplitView` and `.sidebar` list surface directly as the configuration window's root column.
- No custom sidebar background, safe-area extension, rounded perimeter, stroke, or outer container is drawn.
- The configuration surface uses a singleton SwiftUI `Window` with standard macOS titlebar chrome instead of the special `Settings` scene, whose root content is always inset and rounded.
- The existing General/Pets tabs remain in the detail column. The sidebar is visible for Pets and collapses for General, preserving the existing tab behavior.
- The detail pane keeps its existing padding and scroll behavior.
- The sidebar list, selection, Add Pet bar, divider, column width, and all pet behavior remain unchanged.
- Light/Dark adaptation and the user's system accent color remain unchanged.

## Approach

Use SwiftUI's native controls:

1. Change the detail scroll container to `ScrollView(.vertical, showsIndicators: false)`.
2. Replace the special `Settings` scene with an on-demand singleton `Window` and open it with `openWindow(id:)` from the menu.
3. Make `NavigationSplitView` the root of `PetSettingsView`, with `PetSidebar` as its direct sidebar column and the existing `TabView` in the detail column.
4. Collapse the sidebar when General is selected and restore it when Pets is selected. Do not add a background or ignore safe areas around the sidebar.

This is preferred over a custom material background, AppKit bridge, or manual split implementation because it preserves native selection, resizing, scrolling, accessibility, and window integration without creating a second visual surface.

## Verification

- Extend the settings source regression tests to require the dedicated configuration `Window`, `openWindow(id:)`, root split-view composition, and hidden vertical indicator while rejecting `Settings`, `openSettings`, and custom sidebar background/safe-area modifiers.
- Verify the new assertions fail before implementation and pass afterward.
- Run `./scripts/check.sh`.
- Rebuild and launch `dist/Pets.app` with `./scripts/run_app.sh --verify`.
- Capture the real configuration window and confirm the scrollbar is absent and the sidebar reaches the window's top, leading, and bottom content edges with no inset rounded perimeter or containing outline.
