# Settings Scroll and Sidebar Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the Pets detail scrollbar without disabling scrolling and make the native source-list sidebar fill the Settings window's left edge.

**Architecture:** Keep the existing `NavigationSplitView`, `PetSidebar`, and `PetDetailPane`. Hide the detail scroll indicator and extend a dedicated sidebar material background into the Settings safe areas while keeping sidebar content titlebar-safe. No state, persistence, or action behavior changes.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Swift Package Manager.

## Global Constraints

- Preserve vertical scrolling and all keyboard, pointer, trackpad, and accessibility behavior.
- Preserve the existing sidebar width, list selection, Add Pet bar, and detail padding.
- Preserve automatic Light/Dark appearance and system accent behavior.
- Do not add AppKit bridging or a custom split view.

---

### Task 1: Lock and implement the visual refinement

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:172-204`
- Modify: `Sources/Pets/PetSettingsViews.swift:59-61`
- Modify: `Sources/Pets/PetSettingsViews.swift:185-206`

**Interfaces:**
- Consumes: the existing `NavigationSplitView`, `PetSidebar`, and `PetDetailPane` composition.
- Produces: a hidden detail scroll indicator and a sidebar that covers the Settings scene's top, leading, and bottom safe areas.

- [ ] **Step 1: Add failing source-contract assertions**

Add these assertions to `petSettingsUseNativeAdaptiveSidebarAndDetailLayout()`:

```swift
#expect(source.contains("ScrollView(.vertical, showsIndicators: false)"))
#expect(source.contains("EdgeToEdgeSidebarBackground()"))
#expect(source.contains("private struct EdgeToEdgeSidebarBackground: View"))
#expect(source.contains(".ignoresSafeArea(.container, edges: [.top, .leading, .bottom])"))
#expect(!source.contains("PetSidebar(store: store)\n                .ignoresSafeArea"))
#expect(!source.contains("ScrollView {"))
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: the settings layout test fails because the detail still uses `ScrollView {` and the sidebar does not ignore container safe areas.

- [ ] **Step 3: Apply the minimal SwiftUI implementation**

Update the sidebar column without moving its content into the titlebar:

```swift
PetSidebar(store: store)
    .background {
        EdgeToEdgeSidebarBackground()
    }
    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
```

Add the background-only safe-area extension:

```swift
private struct EdgeToEdgeSidebarBackground: View {
    var body: some View {
        Rectangle()
            .fill(.thinMaterial)
            .ignoresSafeArea(.container, edges: [.top, .leading, .bottom])
    }
}
```

Update the detail pane:

```swift
ScrollView(.vertical, showsIndicators: false) {
    // Existing detail content remains unchanged.
}
```

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: all focused tests pass.

- [ ] **Step 5: Run full verification and inspect the real Settings window**

Run:

```bash
./scripts/check.sh
./scripts/run_app.sh --verify
```

Capture the on-screen Pets settings window and confirm the detail scrollbar is absent and the sidebar reaches the top, leading, and bottom window edges.

- [ ] **Step 6: Commit the implementation**

```bash
git add Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift docs/superpowers/plans/2026-07-12-settings-scroll-sidebar-refinement.md
git commit -m "fix: refine settings scrolling and sidebar"
```
