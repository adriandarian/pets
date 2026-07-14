# Sidebar Inline Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rename context-menu action that edits the clicked pet's name inline in the sidebar.

**Architecture:** `PetSidebar` owns the single active rename ID and draft string, while `PetSidebarRow` owns only the text field's focus lifecycle. `PetStore` exposes an ID-targeted name update so the sidebar and existing detail-pane field share normalization and persistence behavior.

**Tech Stack:** Swift 6, SwiftUI for macOS 14, AppKit responder action for select-all, Swift Testing source regressions.

## Global Constraints

- Rename edits only the clicked pet.
- Return and focus loss save; Escape cancels.
- Empty or whitespace-only names fall back to the pet species display name.
- Preserve all unrelated working-tree changes in the shared source and test files.
- Do not commit the implementation because the target files already contain unrelated user changes.

---

### Task 1: Row-Targeted Inline Rename

**Files:**
- Modify: `Sources/Pets/PetSettingsViews.swift:146-232`
- Modify: `Sources/Pets/PetStore.swift:272-280`
- Test: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:240-270`

**Interfaces:**
- Consumes: `PetStore.selectPetInstance(_:)`, `PetStore.updatePetVisibility(_:isVisible:)`, `PetStore.duplicatePet(_:)`, `PetStore.removePet(_:)`, and `PetInstance.ID`.
- Produces: `PetStore.updatePetName(_:name:)`, `PetSidebar.beginRenaming(_:)`, `PetSidebar.commitRename(_:)`, and `PetSidebar.cancelRename(_:)`.

- [ ] **Step 1: Write the failing source regression**

Add this test beside `petSidebarContextMenuTargetsTheClickedPet`:

```swift
@Test
func petSidebarContextMenuSupportsInlineRename() throws {
    let settingsSourceURL = try sourceFile("Sources/Pets/PetSettingsViews.swift")
    let storeSourceURL = try sourceFile("Sources/Pets/PetStore.swift")
    let settingsSource = try String(contentsOf: settingsSourceURL, encoding: .utf8)
    let storeSource = try String(contentsOf: storeSourceURL, encoding: .utf8)

    #expect(settingsSource.contains("Button(\"Rename\")"))
    #expect(settingsSource.contains("beginRenaming(pet)"))
    #expect(settingsSource.contains("petBeingRenamedID == pet.id"))
    #expect(settingsSource.contains("TextField(\"Pet name\", text: $renameDraft)"))
    #expect(settingsSource.contains(".onSubmit(commitRename)"))
    #expect(settingsSource.contains(".onExitCommand {"))
    #expect(settingsSource.contains("isCancellingRename = true"))
    #expect(settingsSource.contains(".onChange(of: isRenameFieldFocused)"))
    #expect(settingsSource.contains("#selector(NSText.selectAll(_:))"))
    #expect(settingsSource.contains("store.updatePetName(id, name: renameDraft)"))
    #expect(storeSource.contains("func updatePetName(_ id: PetInstance.ID, name: String)"))
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests.petSidebarContextMenuSupportsInlineRename
```

Expected: FAIL because Rename, inline field state, focus handlers, and `updatePetName(_:name:)` do not exist.

- [ ] **Step 3: Add the ID-targeted store update**

Replace the selected-only name update with the shared ID-targeted implementation:

```swift
func updatePetName(_ id: PetInstance.ID, name: String) {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    updatePet(id) { pet in
        pet.name = trimmedName.isEmpty
            ? PetCatalog.displayName(for: pet.petID)
            : trimmedName
    }
}

func updateSelectedPetName(_ name: String) {
    guard let selectedPetInstanceID else { return }
    updatePetName(selectedPetInstanceID, name: name)
}
```

- [ ] **Step 4: Add sidebar rename state and context action**

Add transient state to `PetSidebar`:

```swift
@State private var petBeingRenamedID: PetInstance.ID?
@State private var renameDraft = ""
```

Construct each row with the rename state and callbacks:

```swift
PetSidebarRow(
    pet: pet,
    isRenaming: petBeingRenamedID == pet.id,
    renameDraft: $renameDraft,
    commitRename: { commitRename(pet.id) },
    cancelRename: { cancelRename(pet.id) }
)
.tag(pet.id)
.contextMenu {
    Button("Rename") {
        beginRenaming(pet)
    }

    Divider()

    Button(pet.isVisible ? "Hide" : "Show") {
        store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
    }

    Button("Respawn") {
        respawnPet(pet.id)
    }

    Button("Duplicate") {
        store.duplicatePet(pet.id)
    }

    Divider()

    Button("Delete", role: .destructive) {
        store.removePet(pet.id)
    }
}
```

Add the state transitions inside `PetSidebar`:

```swift
private func beginRenaming(_ pet: PetInstance) {
    store.selectPetInstance(pet.id)
    renameDraft = pet.name
    petBeingRenamedID = pet.id
}

private func commitRename(_ id: PetInstance.ID) {
    guard petBeingRenamedID == id else { return }
    store.updatePetName(id, name: renameDraft)
    petBeingRenamedID = nil
    renameDraft = ""
}

private func cancelRename(_ id: PetInstance.ID) {
    guard petBeingRenamedID == id else { return }
    petBeingRenamedID = nil
    renameDraft = ""
}
```

- [ ] **Step 5: Replace the row label with a focused inline field while renaming**

Give `PetSidebarRow` explicit rename inputs and local focus state:

```swift
private struct PetSidebarRow: View {
    let pet: PetInstance
    let isRenaming: Bool
    @Binding var renameDraft: String
    let commitRename: () -> Void
    let cancelRename: () -> Void
    @FocusState private var isRenameFieldFocused: Bool
    @State private var isCancellingRename = false

    var body: some View {
        HStack(spacing: 10) {
            PetSprite(
                petID: pet.petID,
                visualContext: PetVisualContext(
                    status: .idle,
                    hasActiveSessions: true,
                    isHovered: false,
                    animationSettings: pet.animationSettings
                ),
                pixelation: pet.pixelation
            )
            .frame(width: 34, height: 34)

            if isRenaming {
                TextField("Pet name", text: $renameDraft)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .focused($isRenameFieldFocused)
                    .onSubmit(commitRename)
                    .onExitCommand {
                        isCancellingRename = true
                        cancelRename()
                    }
                    .onAppear {
                        isCancellingRename = false
                        isRenameFieldFocused = true
                        DispatchQueue.main.async {
                            NSApp.sendAction(
                                #selector(NSText.selectAll(_:)),
                                to: nil,
                                from: nil
                            )
                        }
                    }
                    .onChange(of: isRenameFieldFocused) { _, isFocused in
                        if !isFocused && isRenaming && !isCancellingRename {
                            commitRename()
                        }
                    }
            } else {
                Text(pet.name)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 6: Run the focused test and verify GREEN**

Run:

```bash
swift test --filter PetOverlayTransparencyTests.petSidebarContextMenuSupportsInlineRename
```

Expected: PASS with the `Pets` executable target compiling successfully.

- [ ] **Step 7: Run complete verification**

Run:

```bash
./scripts/check.sh
```

Expected: all Swift tests pass and `swift build` exits successfully.

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 8: Relaunch the packaged app**

Run:

```bash
./scripts/run_app.sh --verify
```

Expected: `Launched dist/Pets.app`.
