# Native Sidebar Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the inset outlined sidebar surface while preserving the native split-view sidebar and hidden detail scrollbar.

**Architecture:** Keep `NavigationSplitView`, `PetSidebar`, and the `.sidebar` list as the complete sidebar implementation. Delete the custom material background and its safe-area extension so the system owns the sidebar surface and divider.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Swift Package Manager.

## Global Constraints

- Preserve `ScrollView(.vertical, showsIndicators: false)` and vertical scrolling.
- Preserve sidebar selection, width, pet rows, and the Add Pet action.
- Preserve automatic Light/Dark appearance and system accent behavior.
- Do not add a custom background, safe-area extension, rounded perimeter, or AppKit bridge.

---

### Task 1: Restore the native flush sidebar

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:172-205`
- Modify: `Sources/Pets/PetSettingsViews.swift:59-112`

**Interfaces:**
- Consumes: the existing `NavigationSplitView`, `PetSidebar`, and `PetDetailPane` composition.
- Produces: a native sidebar column with no custom containing surface and an unchanged hidden-indicator detail scroll view.

- [ ] **Step 1: Write the failing regression assertions**

Replace the assertions that require `EdgeToEdgeSidebarBackground` with:

```swift
#expect(source.contains("PetSidebar(store: store)\n                .navigationSplitViewColumnWidth"))
#expect(!source.contains("EdgeToEdgeSidebarBackground"))
#expect(!source.contains(".ignoresSafeArea(.container, edges: [.top, .leading, .bottom])"))
#expect(source.contains("ScrollView(.vertical, showsIndicators: false)"))
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: `petSettingsUseNativeAdaptiveSidebarAndDetailLayout()` fails because the custom `EdgeToEdgeSidebarBackground` still exists.

- [ ] **Step 3: Remove the custom sidebar surface**

Change the split-view sidebar composition to:

```swift
PetSidebar(store: store)
    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
```

Delete the complete `EdgeToEdgeSidebarBackground` type. Do not change `PetSidebar`, `PetSidebarRow`, or `PetDetailPane`.

- [ ] **Step 4: Run focused and full verification**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
./scripts/check.sh
```

Expected: both commands exit successfully with zero failures.

- [ ] **Step 5: Verify the real Settings scene**

Run:

```bash
./scripts/run_app.sh --verify
```

Open Settings and confirm the sidebar is a single native left pane with no inset rounded perimeter or containing outline, while the detail view scrolls without a visible scrollbar.

- [ ] **Step 6: Commit the correction**

```bash
git add Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift docs/superpowers/specs/2026-07-12-settings-scroll-sidebar-refinement-design.md docs/superpowers/plans/2026-07-12-native-sidebar-correction.md
git commit -m "fix: restore native settings sidebar"
```
