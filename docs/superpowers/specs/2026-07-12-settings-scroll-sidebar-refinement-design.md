# Settings Scroll and Sidebar Refinement Design

## Summary

Refine the approved native Pets settings layout so the detail pane remains vertically scrollable without displaying a scrollbar, and the source-list sidebar is the flush left pane of the Settings content area without a containing outline.

## Approved Behavior

- Trackpad, mouse-wheel, keyboard, and accessibility scrolling continue to work in the pet detail pane.
- The vertical scroll indicator is never drawn in the detail pane.
- The sidebar uses the native `NavigationSplitView` and `.sidebar` list surface directly.
- No custom sidebar background, safe-area extension, rounded perimeter, stroke, or outer container is drawn.
- The Settings tab/titlebar chrome remains system-owned, and the sidebar begins flush at the native content boundary below it.
- The detail pane keeps its existing padding and scroll behavior.
- The sidebar list, selection, Add Pet bar, divider, column width, and all pet behavior remain unchanged.
- Light/Dark adaptation and the user's system accent color remain unchanged.

## Approach

Use SwiftUI's native controls:

1. Change the detail scroll container to `ScrollView(.vertical, showsIndicators: false)`.
2. Leave `PetSidebar` as the direct `NavigationSplitView` sidebar column. Do not add a background or ignore safe areas around it.

This is preferred over a custom material background, AppKit bridge, or manual split implementation because it preserves native selection, resizing, scrolling, accessibility, and window integration without creating a second visual surface.

## Verification

- Extend the settings source regression test to require the hidden vertical indicator and reject custom sidebar background/safe-area modifiers.
- Verify the new assertions fail before implementation and pass afterward.
- Run `./scripts/check.sh`.
- Rebuild and launch `dist/Pets.app` with `./scripts/run_app.sh --verify`.
- Capture the real `Settings` scene and confirm the scrollbar is absent and the sidebar has no inset rounded perimeter or containing outline.
