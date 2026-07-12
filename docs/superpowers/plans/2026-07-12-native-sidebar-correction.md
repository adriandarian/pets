# Native Sidebar Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pet sidebar a true edge-to-edge window column while preserving the General/Pets tabs and hidden detail scrollbar.

**Architecture:** Replace the special inset `Settings` scene with an on-demand singleton SwiftUI `Window`. Make `NavigationSplitView` the root of `PetSettingsView`, keep the General/Pets `TabView` in its detail column, and show the native `PetSidebar` only for the Pets tab.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Swift Package Manager.

## Global Constraints

- Preserve `ScrollView(.vertical, showsIndicators: false)` and vertical scrolling.
- Preserve sidebar selection, width, pet rows, and the Add Pet action.
- Preserve the General/Pets tab controls and collapse the sidebar on General.
- Preserve automatic Light/Dark appearance and system accent behavior.
- Do not add a custom background, safe-area extension, rounded perimeter, or AppKit bridge.

---

### Task 1: Restore the native flush sidebar

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:88-105`
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:172-205`
- Modify: `Sources/Pets/PetsApp.swift:6-38`
- Modify: `Sources/Pets/PetsApp.swift:208-231`
- Modify: `Sources/Pets/PetSettingsViews.swift:5-112`

**Interfaces:**
- Consumes: the existing `PetSidebar`, General/Pets tab content, `PetDetailPane`, and menu foregrounding callback.
- Produces: an on-demand configuration window whose root native sidebar has no custom containing surface and whose detail scroll view keeps its hidden indicator.

- [ ] **Step 1: Write the failing regression assertions**

Update the menu/scene assertions to require:

```swift
#expect(source.contains("Window(\"Pets\", id: PetsWindowID.configuration)"))
#expect(source.contains("@Environment(\\.openWindow)"))
#expect(source.contains("openWindow(id: PetsWindowID.configuration)"))
#expect(!source.contains("Settings {"))
#expect(!source.contains("@Environment(\\.openSettings)"))
```

Replace the sidebar assertions that require `EdgeToEdgeSidebarBackground` with:

```swift
#expect(source.contains("NavigationSplitView(columnVisibility: $columnVisibility)"))
#expect(source.contains("PetSidebar(store: store)\n            .navigationSplitViewColumnWidth"))
#expect(source.contains("TabView(selection: $selectedTab)"))
#expect(!source.contains("EdgeToEdgeSidebarBackground"))
#expect(!source.contains(".ignoresSafeArea(.container, edges: [.top, .leading, .bottom])"))
#expect(source.contains("ScrollView(.vertical, showsIndicators: false)"))
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: the menu/scene and settings layout tests fail because the app still uses the special `Settings` scene and the split view is nested inside the Pets tab.

- [ ] **Step 3: Implement the dedicated window and root split composition**

Replace the app scene with an on-demand singleton window:

```swift
Window("Pets", id: PetsWindowID.configuration) {
    PetSettingsView(
        store: appDelegate.store,
        toggleOpenAtLogin: { appDelegate.setOpenAtLogin($0) },
        respawnSelectedPet: { appDelegate.respawnSelectedPet() }
    )
}
.windowResizability(.contentSize)
```

Change the menu action to use `@Environment(\.openWindow)` and call:

```swift
openWindow(id: PetsWindowID.configuration)
bringConfigurationToFront()
```

Make the settings root a split view:

```swift
private enum PetSettingsTab: Hashable {
    case general
    case pets
}

struct PetSettingsView: View {
    @ObservedObject var store: PetStore
    let toggleOpenAtLogin: (Bool) -> Void
    let respawnSelectedPet: () -> Void
    @State private var selectedTab = PetSettingsTab.pets
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PetSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            TabView(selection: $selectedTab) {
                GeneralSettingsPane(
                    store: store,
                    toggleOpenAtLogin: toggleOpenAtLogin
                )
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PetSettingsTab.general)

                PetConfigurationDetailPane(
                    store: store,
                    respawnSelectedPet: respawnSelectedPet
                )
                .tabItem {
                    Label("Pets", systemImage: "pawprint")
                }
                .tag(PetSettingsTab.pets)
            }
        }
        .frame(width: 900, height: 620)
        .onChange(of: selectedTab) { _, newTab in
            columnVisibility = newTab == .pets ? .all : .detailOnly
        }
    }
}
```

Rename `PetConfigurationPane` to `PetConfigurationDetailPane` and replace its nested `NavigationSplitView` with the existing detail selection group:

```swift
Group {
    if let selectedPet {
        PetDetailPane(
            store: store,
            pet: selectedPet,
            respawnSelectedPet: respawnSelectedPet,
            changeSprite: { isSpritePickerPresented = true },
            deletePet: { isDeleteConfirmationPresented = true }
        )
    } else {
        EmptyPetCollectionView {
            store.addPet()
        }
    }
}
```

Keep the existing sheet and confirmation-dialog modifiers on that group. Delete the complete `EdgeToEdgeSidebarBackground` type. Do not change `PetSidebarRow` or `PetDetailPane`.

- [ ] **Step 4: Run focused and full verification**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
./scripts/check.sh
```

Expected: both commands exit successfully with zero failures.

- [ ] **Step 5: Verify the real configuration window**

Run:

```bash
./scripts/run_app.sh --verify
```

Open Configure and confirm the sidebar reaches the configuration window's top, leading, and bottom content edges with no inset rounded perimeter or containing outline. Switch to General and back to Pets to confirm the sidebar collapses and restores, then confirm the detail view scrolls without a visible scrollbar.

- [ ] **Step 6: Commit the correction**

```bash
git add Sources/Pets/PetsApp.swift Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift docs/superpowers/specs/2026-07-12-settings-scroll-sidebar-refinement-design.md docs/superpowers/plans/2026-07-12-native-sidebar-correction.md
git commit -m "fix: make settings sidebar flush"
```
