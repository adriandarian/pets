# Flat Pet Settings Sections Design

## Summary

Remove the rounded `GroupBox` backgrounds around Pet Details, Appearance, and Behavior so the configuration detail reads as one native macOS surface instead of a stack of cards.

## Approved Behavior

- Pet Details, Appearance, and Behavior render directly on the detail-pane background.
- Each section keeps a clear `.headline` title and consistent spacing.
- Thin system `Divider` lines separate the three settings sections.
- The name field, segmented style picker, context slider, Change Sprite button, and switches remain native controls with their own standard macOS chrome.
- The sprite preview remains a framed grid canvas because it represents content being previewed, not a settings container.
- The flush sidebar, toolbar selector, hidden detail scrollbar, Light/Dark adaptation, and system accent color remain unchanged.
- No behavior, persistence, action, or accessibility label changes.

## Approach

Introduce a small generic `FlatSettingsSection` view that owns only a title, vertical spacing, and leading alignment. Replace all three `GroupBox` wrappers with this component and add system dividers between the sections in `PetDetailPane`.

This keeps the hierarchy consistent without painting new backgrounds, shadows, strokes, or rounded rectangles behind ordinary settings rows.

## Verification

- Extend the settings source regression test to require all three `FlatSettingsSection` uses and reject `GroupBox` in `PetSettingsViews.swift`.
- Verify the new assertions fail before implementation and pass afterward.
- Run `./scripts/check.sh`.
- Rebuild and launch `dist/Pets.app` with `./scripts/run_app.sh --verify`.
- Capture the real configuration window and confirm the three rounded section backgrounds are gone while controls and the sprite preview remain intact.
