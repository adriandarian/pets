# Pet Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a settings-first pet configuration system with a short menu, per-pet customization, and multiple spawned pet panels.

**Architecture:** Add codable core models for pet instances and animation settings, migrate existing single-pet defaults into a one-item collection, then make the app store publish and persist an array of pet instances. AppKit panel ownership moves from one panel to a dictionary keyed by pet ID, while SwiftUI settings expose pet list/detail editing.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, Swift Testing, `UserDefaults` JSON persistence.

---

### Task 1: Core Pet Instance Model

**Files:**
- Create: `Sources/PetsCore/PetInstance.swift`
- Test: `Tests/PetsCoreTests/PetInstanceTests.swift`

- [ ] **Step 1: Write failing tests for default instance creation, clamping, and final-pet removal policy**

```swift
import Foundation
import Testing
@testable import PetsCore

@Suite
struct PetInstanceTests {
    @Test
    func defaultInstanceUsesExistingCatalogDefaults() {
        let instance = PetInstance.defaultInstance()

        #expect(instance.name == "Cute Cloud")
        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == .off)
        #expect(instance.sessionContextLineCount == 2)
        #expect(instance.animationSettings.isHoverBounceEnabled)
        #expect(instance.animationSettings.isIdleMotionEnabled)
        #expect(instance.animationSettings.areStatusMoodsEnabled)
        #expect(instance.isVisible)
    }

    @Test
    func updatingSpriteClampsPixelationToNewSpriteCapability() {
        var instance = PetInstance.defaultInstance()
        instance.pixelation = .chunky

        instance.updatePetID(.cuteCloud)

        #expect(instance.petID == .cuteCloud)
        #expect(instance.pixelation == .medium)
    }

    @Test
    func contextLineCountIsClampedOnAssignment() {
        var instance = PetInstance.defaultInstance()

        instance.updateSessionContextLineCount(99)

        #expect(instance.sessionContextLineCount == 4)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PetInstanceTests`

Expected: fail because `PetInstance` does not exist.

- [ ] **Step 3: Implement the core model**

Create `PetInstance`, `PetAnimationSettings`, and `PetOverlayPosition` in `Sources/PetsCore/PetInstance.swift`. Make them `Codable`, `Equatable`, and `Sendable`; use `PetCatalog` and `PetSessionContextLineCount` to clamp values.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PetInstanceTests`

Expected: pass.

### Task 2: Store Persistence And Operations

**Files:**
- Modify: `Sources/Pets/PetStore.swift`
- Test: `Tests/PetsCoreTests/PetInstanceTests.swift`

- [ ] **Step 1: Add tests for collection encoding and migration helper behavior**

Add tests proving:

```swift
let instances = [PetInstance.defaultInstance()]
let data = try JSONEncoder().encode(instances)
let decoded = try JSONDecoder().decode([PetInstance].self, from: data)
#expect(decoded == instances)
```

and:

```swift
let migrated = PetInstance.migratedDefault(
    petID: .classicClaude,
    pixelation: .chunky,
    sessionContextLineCount: 3
)
#expect(migrated.petID == .classicClaude)
#expect(migrated.pixelation == .chunky)
#expect(migrated.sessionContextLineCount == 3)
```

- [ ] **Step 2: Run tests to verify they fail where helpers are missing**

Run: `swift test --filter PetInstanceTests`

Expected: fail until migration helper exists.

- [ ] **Step 3: Add store state and mutation APIs**

In `PetStore`, replace global `selectedPetID`, `spritePixelation`, and `sessionContextLineCount` storage with persisted `petInstances` and `selectedPetInstanceID`. Add APIs:

```swift
func addPet()
func removeSelectedPet()
func selectPetInstance(_ id: PetInstance.ID)
func updateSelectedPetName(_ name: String)
func updateSelectedPetID(_ petID: PetID)
func updateSelectedPetPixelation(_ pixelation: PetSpritePixelation)
func updateSelectedPetContextLineCount(_ lineCount: Int)
func updateSelectedPetAnimationSettings(_ settings: PetAnimationSettings)
func updatePetVisibility(_ id: PetInstance.ID, isVisible: Bool)
func updatePetOverlayPosition(_ id: PetInstance.ID, origin: CGPoint, placement: PetOverlayHorizontalPlacement)
```

Keep compatibility computed properties for current overlay code until it is updated:

```swift
var selectedPetID: PetID
var spritePixelation: PetSpritePixelation
var sessionContextLineCount: Int
```

- [ ] **Step 4: Run package tests**

Run: `swift test`

Expected: pass after source-string tests are adjusted in later tasks.

### Task 3: Multiple Panel Ownership

**Files:**
- Modify: `Sources/Pets/PetsApp.swift`
- Modify: `Sources/Pets/PetOverlayView.swift`

- [ ] **Step 1: Update `PetOverlayView` to accept a pet instance ID**

Pass a `PetInstance.ID` into the overlay and derive the instance through the store. Fallback to the selected/default instance if the ID no longer exists.

- [ ] **Step 2: Move `AppDelegate.panel` to `panels`**

Use:

```swift
private var panels: [PetInstance.ID: PetPanel] = [:]
```

Add methods to synchronize visible pet instances to panels, respawn all visible panels, and update panel positions when moved.

- [ ] **Step 3: Build**

Run: `swift build`

Expected: build succeeds.

### Task 4: Menu And Settings UI

**Files:**
- Modify: `Sources/Pets/PetsApp.swift`

- [ ] **Step 1: Simplify menu**

Keep only:

```swift
Button("Respawn Pet") { ... }
Button(store.areAnyPetsVisible ? "Hide Pet" : "Show Pet") { ... }
SettingsLink { Label("Configure...", systemImage: "slider.horizontal.3") }
Divider()
Button("Quit Pets") { NSApplication.shared.terminate(nil) }
```

- [ ] **Step 2: Build full settings view**

Use a native SwiftUI settings layout with tabs or a two-column manual split. Include General and Pets sections. Pets section must show an active-pet list, add/remove buttons, selected pet detail controls, pixelation options, context lines, and animation toggles.

- [ ] **Step 3: Update source-string tests**

Adjust `PetOverlayTransparencyTests` so they assert the new menu is short, settings still exists, overlay uses instance pixelation, and context lines come from the pet instance.

- [ ] **Step 4: Run tests**

Run: `swift test`

Expected: pass.

### Task 5: Final Verification

**Files:**
- No new files.

- [ ] **Step 1: Run full checks**

Run: `swift test`

Expected: pass.

Run: `swift build`

Expected: pass.

- [ ] **Step 2: Manual launch smoke test**

Run: `scripts/run_app.sh`

Expected: app launches, menu contains only four commands, Settings opens, adding a pet creates another overlay, and per-pet settings update only that pet.
