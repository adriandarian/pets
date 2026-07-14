# Pet Collection Family Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Collection into a browse-only, family-aware catalog that clearly distinguishes obtained and missing sprites while keeping all desktop-pet creation in the Pets tab.

**Architecture:** Keep family selection as ephemeral SwiftUI state inside `PetCollectionView` and derive the selected category directly from `PetCatalog.builtInCategories`. Reuse `PetCollectionState` ownership and existing `PetSprite` rendering; no reward-ledger, persistence, or catalog schema changes are required. Update the unlock reveal to a single Done action so Collection never mutates desktop pet instances.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing, macOS 14+, existing `Pets` and `PetsCore` targets.

## Global Constraints

- Collection is browse-only; creating and managing desktop pet instances remains exclusively in the Pets tab.
- The family picker is sourced from `PetCatalog.builtInCategories` and remains visible while Clouds is the only family.
- Obtained cards use full-color sprites plus the exact text `Obtained`.
- Missing cards use subdued sprites, a system lock, and exact text in the form `Missing · Rare`.
- Collection and the unlock reveal contain no Add or Add to Desktop action.
- Keep the 900 x 620 native Settings window, semantic macOS colors, SF Symbols, and existing `PetSprite` assets.
- Do not modify token accounting, chest costs, ownership persistence, duplicate prevention, or the Pets-tab add flow.
- The checkout already contains the uncommitted collection feature and earlier user edits. Do not create an implementation commit that would split dependent feature files or absorb unrelated user work; leave implementation changes unstaged for user review.

---

### Task 1: Add family filtering and explicit ownership states

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift:17-38`
- Modify: `Sources/Pets/PetCollectionViews.swift:4-45`
- Modify: `Sources/Pets/PetCollectionViews.swift:313-383`

**Interfaces:**
- Consumes: `PetCatalog.builtInCategories: [PetCatalogCategory]`, `PetCatalogCategory.id`, `PetCatalogCategory.petIDs`, `PetStore.isPetOwned(_:) -> Bool`, and `PetCatalog.rarity(for:) -> PetRarity`.
- Produces: `PetCollectionView.selectedCategory: PetCatalogCategory`, `PetCollectionView.selectedFamilyOwnedCount: Int`, and a browse-only `PetCollectionCard` with obtained or missing status.

- [ ] **Step 1: Write the failing family-browser source test**

Replace the current `collectionHubContainsTheCoreRewardJourney()` test with the existing reward assertions plus a separate focused test:

```swift
@Test
func collectionHubContainsTheCoreRewardJourney() throws {
    let source = try source("Sources/Pets/PetCollectionViews.swift")

    #expect(source.contains("struct PetCollectionView: View"))
    #expect(source.contains("ProgressView(value: store.collectionState.progressFraction)"))
    #expect(source.contains("store.refreshRewardUsage()"))
    #expect(source.contains("ForEach(PetRarity.allCases"))
    #expect(source.contains("store.openChest(rarity)"))
    #expect(source.contains("PetArtResourceLocator.url(for:"))
    #expect(source.contains("\"Pet Collection\""))
    #expect(source.contains("UnlockedPetSheet"))
}

@Test
func collectionBrowsesOneCatalogFamilyAtATime() throws {
    let source = try source("Sources/Pets/PetCollectionViews.swift")

    #expect(source.contains("@State private var selectedCategoryID"))
    #expect(source.contains("Picker(\"Pet family\", selection: $selectedCategoryID)"))
    #expect(source.contains("ForEach(PetCatalog.builtInCategories"))
    #expect(source.contains("ForEach(selectedCategory.petIDs"))
    #expect(source.contains("\"Obtained\""))
    #expect(source.contains("\"Missing · \\(PetCatalog.rarity(for: petID).displayName)\""))
    #expect(!source.contains("Label(\"Add\", systemImage: \"plus\")"))
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PetCollectionViewSourceTests.collectionBrowsesOneCatalogFamilyAtATime
```

Expected: FAIL because `PetCollectionView` has no `selectedCategoryID`, no family picker, and still renders an Add button.

- [ ] **Step 3: Add ephemeral family selection and filter the grid**

Add family state immediately below the store property:

```swift
@ObservedObject var store: PetStore
@State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id
```

Replace the current Pet Collection section with:

```swift
VStack(alignment: .leading, spacing: 12) {
    sectionHeader(
        "Pet Collection",
        detail: "\(selectedFamilyOwnedCount) of \(selectedCategory.petIDs.count) obtained"
    )

    Picker("Pet family", selection: $selectedCategoryID) {
        ForEach(PetCatalog.builtInCategories, id: \.id) { category in
            Text(category.displayName)
                .tag(Optional(category.id))
        }
    }
    .pickerStyle(.segmented)

    LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 142), spacing: 12)],
        spacing: 12
    ) {
        ForEach(selectedCategory.petIDs, id: \.self) { petID in
            PetCollectionCard(store: store, petID: petID)
        }
    }
}
```

Replace `ownedCatalogCount` with the family-derived properties:

```swift
private var selectedCategory: PetCatalogCategory {
    PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
        ?? PetCatalog.builtInCategories[0]
}

private var selectedFamilyOwnedCount: Int {
    selectedCategory.petIDs.count(where: store.isPetOwned)
}
```

- [ ] **Step 4: Replace card actions with obtained and missing labels**

In `PetCollectionCard`, replace the top-trailing lock block with a status symbol for both states:

```swift
Image(systemName: isOwned ? "checkmark.circle.fill" : "lock.fill")
    .font(.caption.weight(.semibold))
    .foregroundStyle(isOwned ? Color.accentColor : Color.secondary)
    .padding(7)
    .accessibilityLabel(isOwned ? "Obtained" : "Missing")
```

Replace the Add button / rarity branch with:

```swift
if isOwned {
    Label("Obtained", systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.accentColor)
        .frame(height: 22)
} else {
    Label(
        "Missing · \(PetCatalog.rarity(for: petID).displayName)",
        systemImage: "lock.fill"
    )
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(height: 22)
}
```

Keep the existing full-color versus desaturated sprite treatment and card background. Do not add a tap gesture or button wrapper.

- [ ] **Step 5: Run the focused suite and verify GREEN**

Run:

```bash
swift test --filter PetCollectionViewSourceTests
```

Expected: all `PetCollectionViewSourceTests` pass, including family filtering and the absence of card Add controls.

- [ ] **Step 6: Review the unstaged Task 1 diff**

Run:

```bash
git diff --check -- Sources/Pets/PetCollectionViews.swift Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift
git diff -- Sources/Pets/PetCollectionViews.swift Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift
```

Expected: no whitespace errors; only the family-browser UI and source-test assertions are added. Do not stage or commit because these files are part of the existing uncommitted collection feature.

---

### Task 2: Make the unlock reveal browse-only

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift:17-50`
- Modify: `Sources/Pets/PetCollectionViews.swift:385-440`

**Interfaces:**
- Consumes: `PetStore.dismissUnlockedPet()` and existing `UnlockedPetSheet` presentation binding.
- Produces: a reveal sheet with exactly one user action, `Done`, and no call to `PetStore.addPet(petID:)` from Collection.

- [ ] **Step 1: Write the failing reveal test**

Add:

```swift
@Test
func unlockRevealIsBrowseOnly() throws {
    let source = try source("Sources/Pets/PetCollectionViews.swift")

    #expect(source.contains("Button(\"Done\")"))
    #expect(!source.contains("Add to Desktop"))
    #expect(!source.contains("store.addPet(petID: petID)"))
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PetCollectionViewSourceTests.unlockRevealIsBrowseOnly
```

Expected: FAIL because the reveal still contains `Add to Desktop` and calls `store.addPet(petID:)`.

- [ ] **Step 3: Replace reveal actions with one Done button**

Replace the reveal `HStack` with:

```swift
Button("Done") {
    store.dismissUnlockedPet()
}
.buttonStyle(.borderedProminent)
.keyboardShortcut(.defaultAction)
```

Do not change the unlocked sprite, name, rarity, sheet size, or presentation binding.

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run:

```bash
swift test --filter PetCollectionViewSourceTests
```

Expected: all source tests pass and `PetCollectionViews.swift` contains no Add action.

- [ ] **Step 5: Confirm the Pets tab still owns desktop creation**

Run:

```bash
rg -n 'Add Pet|store\.addPet|updateSelectedPetID' Sources/Pets/PetSettingsViews.swift Sources/Pets/PetCollectionViews.swift
```

Expected: Add Pet remains in `PetSettingsViews.swift`; `PetCollectionViews.swift` has no `store.addPet` call.

- [ ] **Step 6: Review the unstaged Task 2 diff**

Run:

```bash
git diff --check -- Sources/Pets/PetCollectionViews.swift Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift
```

Expected: no whitespace errors. Do not stage or commit for the same dirty-worktree constraint described in Task 1.

---

### Task 3: Verify the packaged family browser and pass visual QA

**Files:**
- Modify: `design-qa.md`
- Create locally: `.artifacts/pet-collection-family-browser/source.png`
- Create locally: `.artifacts/pet-collection-family-browser/implementation.png`
- Create locally: `.artifacts/pet-collection-family-browser/comparison-source-vs-implementation.png`

**Interfaces:**
- Consumes: the user reference screenshot at `/var/folders/2v/kqphmbr97dncsd1cny9994j40000gn/T/codex-clipboard-4d0c758d-7e05-4bc1-a4fb-23ba763341a9.png`, `./scripts/check.sh`, `./scripts/run_app.sh --verify`, and the native Collection tab.
- Produces: a freshly launched `dist/Pets.app`, interaction evidence for the family browser, and a root `design-qa.md` ending in exact text `final result: passed` only when no P0/P1/P2 issue remains.

- [ ] **Step 1: Run the complete repository verification**

Run:

```bash
./scripts/check.sh
```

Expected: all Swift tests pass and the final `swift build` exits 0.

- [ ] **Step 2: Rebuild and launch the packaged app**

Run:

```bash
./scripts/run_app.sh --verify
```

Expected: output ends with `Launched dist/Pets.app` and the running process path is `dist/Pets.app/Contents/MacOS/Pets`.

- [ ] **Step 3: Exercise the native Collection flow with Computer Use**

In the packaged app:

1. Open Settings and select Collection.
2. Confirm the segmented `Cloud Pets` family picker is visible.
3. Confirm the header reads `3 of 5 obtained` for the current persisted state.
4. Confirm Cumulus, Nimbus, and Snow show full-color sprites plus `Obtained`.
5. Confirm Cirrus and Lenticular show subdued sprites plus `Missing · Rare`.
6. Confirm no collection card has an Add button.
7. If a chest can be opened without manufacturing tokens or keys, confirm its reveal has only Done; otherwise rely on the source regression test for that persisted-state-dependent interaction.
8. Confirm the Pets tab still exposes Add Pet and owned-sprite selection.

- [ ] **Step 4: Capture source and implementation evidence**

Create `.artifacts/pet-collection-family-browser/`, copy the supplied screenshot to `source.png`, and save a 900 x 672 native Collection screenshot to `implementation.png`. The implementation capture must show the family picker, family progress, obtained state, and missing state in one readable frame.

- [ ] **Step 5: Build and inspect one combined comparison input**

Place `source.png` and `implementation.png` side by side in a local comparison page or image, save the rendered result as `comparison-source-vs-implementation.png`, and inspect that combined image. Check typography, spacing, semantic colors, sprite sharpness, exact copy, lock/check symbols, and the absence of Add controls.

Expected: the implementation preserves the screenshot's five-card family row while replacing the former action strip with explicit ownership status and adding the approved native family picker. Any P0/P1/P2 issue blocks handoff and must be fixed, recaptured, and compared again.

- [ ] **Step 6: Rewrite the root QA report with the new evidence**

Update `design-qa.md` to include:

```markdown
# Pet Collection Family Browser design QA

## Evidence

- Source visual truth: `.artifacts/pet-collection-family-browser/source.png`.
- Rendered implementation: `.artifacts/pet-collection-family-browser/implementation.png`.
- Combined comparison: `.artifacts/pet-collection-family-browser/comparison-source-vs-implementation.png`.
- Viewport: 900 x 672 native app screenshot.
- State: Cloud Pets family, persisted 3 of 5 ownership state.

## Required fidelity surfaces

- Typography: Native system hierarchy remains consistent with the approved Collection screen and every status label is legible without truncation.
- Spacing and layout rhythm: The family picker, progress text, and five-card Cloud Pets grid fit the 900 x 672 capture without horizontal clipping.
- Colors and visual tokens: Obtained and missing states use semantic accent and secondary colors with sufficient dark-mode contrast.
- Image quality and asset fidelity: Existing `PetSprite` assets remain sharp; obtained sprites stay full color and missing sprites remain recognizable when desaturated.
- Copy and content: The selected family reads Cloud Pets, progress reads 3 of 5 obtained, and cards use only Obtained or Missing plus rarity.

## Interaction verification

- Family picker is visible and filters the selected category.
- Obtained and missing status is explicit.
- Collection contains no Add action.
- Unlock reveal is browse-only.
- Pets retains desktop-pet creation.

## Comparison history

1. Pass 1: The source and packaged implementation were compared together at readable scale. Record any P0/P1/P2 finding and its post-fix recapture here; otherwise state that none were found.

final result: passed
```

Adjust the expected findings only when the combined comparison provides different evidence. If source capture, implementation capture, comparison, or any P0/P1/P2 fix is blocked, use exact final text `final result: blocked` and name the blocker.

- [ ] **Step 7: Run final hygiene checks**

Run:

```bash
git diff --check
rg -n 'Add to Desktop|Label\("Add"|store\.addPet\(petID: petID\)' Sources/Pets/PetCollectionViews.swift
tail -n 1 design-qa.md
git status --short --branch
```

Expected: `git diff --check` exits 0; the Collection search returns no matches; the QA report ends with `final result: passed`; and all implementation changes remain unstaged alongside the pre-existing workspace changes.
