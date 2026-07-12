# Settings Scroll and Sidebar Refinement Design

## Summary

Refine the approved native Pets settings layout so the detail pane remains vertically scrollable without displaying a scrollbar, and the source-list sidebar visually occupies the full left edge of the Settings window without an inset container around it.

## Approved Behavior

- Trackpad, mouse-wheel, keyboard, and accessibility scrolling continue to work in the pet detail pane.
- The vertical scroll indicator is never drawn in the detail pane.
- The sidebar extends through the Settings scene's top, leading, and bottom container safe areas.
- Sidebar content remains inside the titlebar-safe layout region so it never overlaps traffic lights or the sidebar toggle.
- The detail pane keeps its existing padding and scroll behavior.
- The sidebar list, selection, Add Pet bar, divider, column width, and all pet behavior remain unchanged.
- Light/Dark adaptation and the user's system accent color remain unchanged.

## Approach

Use SwiftUI's native controls:

1. Change the detail scroll container to `ScrollView(.vertical, showsIndicators: false)`.
2. Give `PetSidebar` an `EdgeToEdgeSidebarBackground` whose native material ignores the top, leading, and bottom container safe areas. Only the background extends; list content retains normal safe-area positioning.

This is preferred over an AppKit `NSScrollView` bridge or a custom split implementation because it preserves native selection, resizing, scrolling, and accessibility with no new state or platform glue.

## Verification

- Extend the settings source regression test to require the hidden vertical indicator and edge-to-edge sidebar modifiers.
- Verify the new assertions fail before implementation and pass afterward.
- Run `./scripts/check.sh`.
- Rebuild and launch `dist/Pets.app` with `./scripts/run_app.sh --verify`.
- Capture the real `Settings` scene and confirm the scrollbar is absent while the sidebar reaches the window edges.
