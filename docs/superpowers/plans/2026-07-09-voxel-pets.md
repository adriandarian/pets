# Voxel Pets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three built-in code-native voxel pets to the existing Pets catalog, picker, previews, and overlay renderer.

**Architecture:** Extend `PetID`, `PetRenderFamily`, and `PetCatalog.entries` with an additive `voxel-pets` family. Route `.voxel` pets in `PetSprite` to a new SwiftUI renderer that uses the existing 128-unit sprite coordinate system, `petShadow(unit:)`, `statusColor(_:)`, and pixelation wrapper.

**Tech Stack:** Swift 6 package, SwiftUI, AppKit-backed pixelation rasterizer, `swift-testing`.

## Global Constraints

- Do not change the pet instance persistence schema.
- Do not add external image files or sprite sheets.
- Keep settings layout unchanged; the picker should discover the category through `PetCatalog.builtInCategories`.
- New voxel pet IDs are additive: `voxelCat`, `voxelSlime`, and `voxelDragon`.
- All three voxel pets support `.chunky` maximum pixelation.
- Preserve unrelated dirty working-tree changes.

---

### Task 1: Catalog Voxel Family

**Files:**
- Create: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Test: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`

**Interfaces:**
- Consumes: `PetID`, `PetCatalog`, `PetInstance`, `PetSpritePixelation`
- Produces: `PetID.voxelCat`, `PetID.voxelSlime`, `PetID.voxelDragon`, `PetRenderFamily.voxel`

- [ ] **Step 1: Write the failing catalog tests**

```swift
import Testing
@testable import PetsCore

@Suite
struct PetCatalogTests {
    @Test
    func builtInCategoriesIncludeVoxelPetsInOrder() throws {
        let category = try #require(PetCatalog.builtInCategories.first { $0.id == "voxel-pets" })

        #expect(category.displayName == "Voxel Pets")
        #expect(category.petIDs == [.voxelCat, .voxelSlime, .voxelDragon])
    }

    @Test
    func voxelPetsExposeDisplayNamesAndChunkyPixelation() {
        #expect(PetCatalog.displayName(for: .voxelCat) == "Voxel Cat")
        #expect(PetCatalog.displayName(for: .voxelSlime) == "Voxel Slime")
        #expect(PetCatalog.displayName(for: .voxelDragon) == "Voxel Dragon")

        #expect(PetCatalog.maximumPixelation(for: .voxelCat) == .chunky)
        #expect(PetCatalog.maximumPixelation(for: .voxelSlime) == .chunky)
        #expect(PetCatalog.maximumPixelation(for: .voxelDragon) == .chunky)
    }

    @Test
    func voxelPetInstancesPreserveChunkyPixelation() {
        let instance = PetInstance(
            name: "Voxel Cat",
            petID: .voxelCat,
            pixelation: .chunky,
            sessionContextLineCount: 2
        )

        #expect(instance.petID == .voxelCat)
        #expect(instance.pixelation == .chunky)
    }
}
```

- [ ] **Step 2: Run catalog tests to verify they fail**

Run: `swift test --filter PetCatalogTests`

Expected: FAIL because `PetID` has no `voxelCat`, `voxelSlime`, or `voxelDragon` members.

- [ ] **Step 3: Add catalog IDs, entries, category, and render family**

Add to `PetID`:

```swift
public static let voxelCat = PetID(rawValue: "voxel-cat")
public static let voxelSlime = PetID(rawValue: "voxel-slime")
public static let voxelDragon = PetID(rawValue: "voxel-dragon")
```

Add to `PetRenderFamily`:

```swift
case voxel
```

Add three `PetCatalogEntry` values with `categoryID: "voxel-pets"`, `renderFamily: .voxel`, and `maximumPixelation: .chunky`.

Add the category after `cozy-pets`:

```swift
PetCatalogCategory(
    id: "voxel-pets",
    displayName: "Voxel Pets",
    petIDs: [
        .voxelCat,
        .voxelSlime,
        .voxelDragon
    ]
)
```

- [ ] **Step 4: Run catalog tests to verify they pass**

Run: `swift test --filter PetCatalogTests`

Expected: PASS.

---

### Task 2: Voxel Sprite Routing and Renderer

**Files:**
- Create: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`
- Modify: `Sources/Pets/PetSprites.swift`
- Test: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`

**Interfaces:**
- Consumes: `PetCatalog.renderFamily(for:)`, `PetRenderFamily.voxel`, `PetID.voxelCat`, `PetID.voxelSlime`, `PetID.voxelDragon`, `statusColor(_:)`
- Produces: `VoxelPetSprite`, helper methods `voxelCat(unit:)`, `voxelSlime(unit:)`, `voxelDragon(unit:)`

- [ ] **Step 1: Write the failing source-inspection tests**

```swift
import Foundation
import Testing

@Suite
struct PetSpriteSourceTests {
    @Test
    func petSpriteRoutesVoxelPetsToVoxelRenderer() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("case .voxel:"))
        #expect(source.contains("VoxelPetSprite(petID: petID, status: status, isExcited: isExcited)"))
    }

    @Test
    func voxelRendererDefinesAllVoxelPetsAndUsesStatusTint() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("private struct VoxelPetSprite: View"))
        #expect(source.contains("case .voxelCat:"))
        #expect(source.contains("case .voxelSlime:"))
        #expect(source.contains("case .voxelDragon:"))
        #expect(source.contains("private var statusTint: Color"))
        #expect(source.contains("statusColor(status == .unknown ? .idle : status)"))
    }

    private func source(_ path: String) throws -> String {
        let url = try repositoryRoot().appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while currentURL.path != "/" {
            if FileManager.default.fileExists(atPath: currentURL.appending(path: "Package.swift").path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
```

- [ ] **Step 2: Run sprite source tests to verify they fail**

Run: `swift test --filter PetSpriteSourceTests`

Expected: FAIL because `PetSprites.swift` does not route `.voxel` and does not define `VoxelPetSprite`.

- [ ] **Step 3: Route `.voxel` in `PetSprite`**

Add this case to the `switch PetCatalog.renderFamily(for: petID)`:

```swift
case .voxel:
    VoxelPetSprite(petID: petID, status: status, isExcited: isExcited)
```

- [ ] **Step 4: Implement `VoxelPetSprite`**

Add a private renderer near the other family renderers in `Sources/Pets/PetSprites.swift`.

The renderer must:

- Use `GeometryReader` and `let unit = min(proxy.size.width, proxy.size.height) / 128`.
- Draw `petShadow(unit: unit)`.
- Switch on `.voxelCat`, `.voxelSlime`, and `.voxelDragon`.
- Offset upward by `-5 * unit` when excited.
- Use `statusTint` from `statusColor(status == .unknown ? .idle : status)`.
- Draw blocky shapes with `Rectangle`, `RoundedRectangle` with small radii, and simple `Path` polygons.

- [ ] **Step 5: Run sprite source tests to verify they pass**

Run: `swift test --filter PetSpriteSourceTests`

Expected: PASS.

---

### Task 3: Full Verification

**Files:**
- Verify: all changed files

**Interfaces:**
- Consumes: tasks 1 and 2
- Produces: verified package test and build output

- [ ] **Step 1: Run focused tests**

Run: `swift test --filter PetCatalogTests && swift test --filter PetSpriteSourceTests`

Expected: both commands exit 0.

- [ ] **Step 2: Run repository check**

Run: `./scripts/check.sh`

Expected: `swift test` exits 0 and `swift build` exits 0.

- [ ] **Step 3: Inspect final diff**

Run: `git diff -- Sources/PetsCore/Pets/PetCatalog.swift Sources/Pets/PetSprites.swift Tests/PetsCoreTests/Pets/PetCatalogTests.swift Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift docs/superpowers/plans/2026-07-09-voxel-pets.md`

Expected: diff contains only the voxel pet implementation, tests, and this plan.
