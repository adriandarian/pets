# Native Adaptive Pet Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom fixed-dark Pets dashboard with the approved native macOS sidebar/detail settings interface that automatically follows system Light or Dark appearance.

**Architecture:** Keep `PetSettingsView`, `PetStore`, the settings scene, and all persistence boundaries intact. Recompose the Pets tab around `NavigationSplitView`, a native source-list sidebar, and focused adaptive detail sections; use existing store methods and bindings for all behavior. Source-level tests lock the macOS structure and prevent forced appearance or fixed-palette regressions.

**Tech Stack:** Swift 6, SwiftUI, AppKit dynamic colors, Swift Testing, Swift Package Manager.

## Global Constraints

- Preserve the existing General and Pets settings tabs.
- Preserve every existing Pets action and setting.
- Do not add a manual appearance preference.
- Do not change `PetStore`, persistence, pet catalog, menu commands, or overlay behavior.
- Use semantic system colors, materials, typography, controls, and the user's macOS accent color.
- Keep the Settings window at `900 × 620` unless build or runtime evidence requires a small adjustment.

---

### Task 1: Lock the native adaptive settings contract

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:172-218`

**Interfaces:**
- Consumes: `Sources/Pets/PetSettingsViews.swift` as source text.
- Produces: regression coverage for native sidebar structure, adaptive appearance, preserved controls, and retired carousel/palette components.

- [ ] **Step 1: Replace the old carousel visual assertions with a failing adaptive-layout test**

Use this contract in `petSettingsUseNativeAdaptiveSidebarAndDetailLayout()`:

```swift
#expect(source.contains("NavigationSplitView"))
#expect(source.contains("private struct PetSidebar: View"))
#expect(source.contains("List(selection: selectedPetBinding)"))
#expect(source.contains(".listStyle(.sidebar)"))
#expect(source.contains("private struct PetDetailPane: View"))
#expect(source.contains("SpritePreviewGridBackground()"))
#expect(source.contains("Color(nsColor: .separatorColor)"))
#expect(source.contains("Menu {"))
#expect(source.contains("Button(\"Duplicate\")"))
#expect(source.contains("Button(\"Delete\", role: .destructive)"))
#expect(source.contains("Button(\"Change Sprite...\")"))
#expect(source.contains("SettingSwitchRow(\"Hover bounce\""))
#expect(source.contains(".toggleStyle(.switch)"))
#expect(source.contains("TextField(\"\", text: nameBinding)"))
#expect(source.contains("EmptyPetCollectionView"))
#expect(!source.contains(".preferredColorScheme("))
#expect(!source.contains("SettingsDesignPalette"))
#expect(!source.contains("GradientSettingsToggleStyle"))
#expect(!source.contains("PetInstanceCarouselView"))
#expect(!source.contains("ScrollView(.horizontal"))
```

- [ ] **Step 2: Replace the overflow test with a focused native selection test**

Use `petSidebarSelectionUsesStoreAsSourceOfTruth()` and assert:

```swift
#expect(source.contains("get: { store.selectedPetInstanceID }"))
#expect(source.contains("store.selectPetInstance(selectedID)"))
#expect(source.contains("ForEach(store.petInstances)"))
#expect(source.contains("PetSidebarRow(pet: pet)"))
#expect(source.contains("store.addPet()"))
#expect(!source.contains("carouselContentWidth"))
#expect(!source.contains("PetCarouselArrow"))
```

- [ ] **Step 3: Run the focused suite and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: the new settings assertions fail because `PetSettingsViews.swift` still forces `.dark`, uses `SettingsDesignPalette`, and renders `PetInstanceCarouselView` instead of `NavigationSplitView` and `PetSidebar`.

---

### Task 2: Implement the native adaptive Pets settings surface

**Files:**
- Modify: `Sources/Pets/PetSettingsViews.swift:5-768`
- Test: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

**Interfaces:**
- Consumes: `PetStore.petInstances`, `selectedPetInstanceID`, `selectedPetInstance`, `selectPetInstance(_:)`, `addPet()`, `duplicateSelectedPet()`, `removeSelectedPet()`, existing update methods, and the `respawnSelectedPet` closure.
- Produces: `PetSidebar`, `PetSidebarRow`, `PetDetailPane`, `PetPreview`, `PetDetailsSection`, `PetAppearanceSection`, and `PetBehaviorSection` SwiftUI views.

- [ ] **Step 1: Make the settings shell appearance-neutral**

Keep the tab content and frame, but remove the fixed tint and forced color scheme:

```swift
TabView {
    GeneralSettingsPane(...)
        .tabItem { Label("General", systemImage: "gearshape") }
    PetConfigurationPane(...)
        .tabItem { Label("Pets", systemImage: "pawprint") }
}
.frame(width: 900, height: 620)
.scenePadding()
```

Delete `SettingsDesignPalette` entirely.

- [ ] **Step 2: Replace the carousel root with a split view**

Compose `PetConfigurationPane.body` with:

```swift
NavigationSplitView {
    PetSidebar(store: store)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
} detail: {
    if let selectedPet {
        PetDetailPane(
            store: store,
            pet: selectedPet,
            respawnSelectedPet: respawnSelectedPet,
            changeSprite: { isSpritePickerPresented = true },
            deletePet: { isDeleteConfirmationPresented = true }
        )
    } else {
        EmptyPetCollectionView { store.addPet() }
    }
}
```

Retain the existing sprite-picker sheet and delete confirmation dialog on the split-view root.

- [ ] **Step 3: Add the native sidebar and selection binding**

Implement `PetSidebar` with a `.sidebar` list and bottom Add Pet button. The binding setter must unwrap the selected ID and call `store.selectPetInstance(selectedID)`. Each `PetSidebarRow` must show a 32-point `PetSprite`, pet name, and semantic `Visible`/`Hidden` secondary text without custom card backgrounds.

- [ ] **Step 4: Add the detail header and compact command menu**

Implement a header with the selected pet name and `<family> · <visibility> · Session aware`. Keep `Respawn` prominent, keep Show/Hide visible, and put Duplicate and destructive Delete in:

```swift
Menu {
    Button("Duplicate") { store.duplicateSelectedPet() }
    Divider()
    Button("Delete", role: .destructive) { deletePet() }
} label: {
    Image(systemName: "ellipsis.circle")
}
.menuStyle(.borderlessButton)
.help("More pet actions")
```

- [ ] **Step 5: Build the adaptive preview and settings groups**

Render the pet with the existing live visual context. Use a rounded preview surface filled with `Color(nsColor: .controlBackgroundColor)` and stroke it with `Color(nsColor: .separatorColor)`. Update the grid canvas stroke to `Color(nsColor: .separatorColor).opacity(0.45)`.

Use focused `GroupBox` sections for Pet Details, Appearance, and Behavior. Reuse the existing name, pixelation, context slider, animation, and sprite-picker bindings. Use default SwiftUI controls; `SettingSwitchRow` must apply `.toggleStyle(.switch)` and must not define a custom `ToggleStyle`.

- [ ] **Step 6: Make the sprite-picker selection adaptive**

Replace fixed selected fills and borders with semantic selection treatment using `Color.accentColor.opacity(...)`, `.quaternary`, and `Color.accentColor`; do not introduce fixed RGB colors.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: all focused tests pass with no build errors.

- [ ] **Step 8: Review and commit the implementation**

Run `git diff --check` and inspect `git diff`. Then commit:

```bash
git add Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift docs/superpowers/plans/2026-07-12-native-adaptive-pet-settings.md
git commit -m "feat: adopt native adaptive pet settings"
```

---

### Task 3: Verify the complete goal against source and runtime evidence

**Files:**
- Verify: `Sources/Pets/PetSettingsViews.swift`
- Verify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

**Interfaces:**
- Consumes: the completed source, repository checks, and packaged application.
- Produces: evidence for every acceptance criterion in the design spec.

- [ ] **Step 1: Prove the fixed appearance and palette are absent**

Run:

```bash
rg -n "preferredColorScheme|SettingsDesignPalette|GradientSettingsToggleStyle|Color\(red:" Sources/Pets/PetSettingsViews.swift
```

Expected: no matches.

- [ ] **Step 2: Run full repository verification**

Run:

```bash
./scripts/check.sh
```

Expected: build and all tests pass.

- [ ] **Step 3: Package and launch the real app**

Run:

```bash
./scripts/run_app.sh --verify
```

Expected: `dist/Pets.app` is built and the Pets process is observed running.

- [ ] **Step 4: Inspect the running settings surface**

Open Configure from the menu-bar app, confirm the settings window foregrounds, and visually compare the native sidebar/detail page with the approved mockup in the machine's current appearance. Confirm all controls remain reachable and the source contains no appearance override, which proves future system appearance changes inherit automatically.

- [ ] **Step 5: Stop the verification process and audit the goal**

Stop only the process launched for verification, inspect `git status --short`, and map each acceptance criterion in the design spec to source, test, build, or runtime evidence before marking the goal complete.
