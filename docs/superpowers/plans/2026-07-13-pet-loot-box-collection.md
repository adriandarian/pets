# Pet Loot Box Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to execute this plan task-by-task with review checkpoints.

**Goal:** Ship the approved native Collection Hub so 500M combined Claude/Codex tokens earn a Common Key, keys upgrade upward at 5:1, and rarity chests unlock non-duplicate pets of their exact tier.

**Architecture:** Put reward economy, catalog rarity, usage readings, and pure parsers in `PetsCore`; keep `UserDefaults`, refresh orchestration, and SwiftUI presentation in the `Pets` executable. Persist a single normalized collection state, apply provider readings idempotently, and expose the result through `PetStore` to a new third settings tab.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Foundation `Process`, Swift Testing, SwiftPM resources, OpenAI ImageGen PNG assets.

---

## Global Constraints

- One Common Key is earned per exactly `500_000_000` newly observed combined tokens, with remainder carried forward.
- Cumulus and every already-configured pet are always normalized into ownership.
- Five Common Keys upgrade to one Rare Key; five Rare Keys upgrade to one Legendary Key.
- Every chest costs one key matching its rarity, and its reward is filtered to that exact rarity.
- A chest can only select an unowned catalog pet of its rarity; an exhausted tier or insufficient balance spends nothing.
- The first successful reading for a provider period counts that period's current total. Reapplying a reading or observing a lower corrected total adds zero.
- Claude comes from `build-cli usage --period weekly --format json --no-cache --no-update-check`; Codex comes from local session JSONL cumulative token events.
- Copilot and Antigravity are not counted until their CLIs expose trustworthy token totals.
- Preserve the existing adaptive native settings design and all unrelated user changes in the dirty worktree.
- Use individual generated transparent chest PNGs. Do not crop the approved contact sheet.

### Task 1: Add rarity to the pet catalog

**Files:**
- Create: `Sources/PetsCore/Pets/PetRarity.swift`
- Modify: `Sources/PetsCore/Pets/PetDefinition.swift`
- Modify: `Sources/PetsCore/Pets/Definitions/CloudPetDefinitions.swift`
- Modify: `Sources/PetsCore/Pets/PetCatalog.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetDefinitionTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetCatalogTests.swift`

- [ ] Write failing tests for the agreed rarity assignments, the 5:1 upgrade path, and rarity filtering.
- [ ] Run `swift test --filter 'PetDefinitionTests|PetCatalogTests'` and confirm the new tests fail for missing APIs.
- [ ] Add `PetRarity: String, Codable, CaseIterable, Sendable` with display name and upgrade target.
- [ ] Add `rarity` to `PetDefinition` and every cloud definition.
- [ ] Add `PetCatalog.rarity(for:)` and `PetCatalog.petIDs(for:)`.
- [ ] Rerun focused tests and confirm they pass.

### Task 2: Implement the idempotent reward ledger

**Files:**
- Create: `Sources/PetsCore/Pets/PetCollectionState.swift`
- Create: `Tests/PetsCoreTests/Pets/PetCollectionStateTests.swift`

- [ ] Write failing tests for starter/grandfather ownership, 500M threshold/remainder math, combined providers, repeated/lower readings, period rollover, 5:1 upgrades, matching-rarity key spend, non-duplicates, exhausted tiers, and insufficient keys.
- [ ] Run `swift test --filter PetCollectionStateTests` and confirm failure.
- [ ] Implement `PetUsageReading`, `PetUsageCheckpoint`, `PetKeyInventory`, `PetCollectionState`, and typed upgrade/chest errors.
- [ ] Make `apply(_:)` return the number of newly earned keys and preserve the highest observed total for a period.
- [ ] Make key upgrades and chest opening validate before mutation; chest opening accepts a deterministic selection index for tests.
- [ ] Rerun the focused tests and confirm they pass.

### Task 3: Read Claude and Codex weekly token totals

**Files:**
- Create: `Sources/PetsCore/Usage/PetUsageSources.swift`
- Create: `Sources/PetsCore/Usage/BuildCLIUsageSource.swift`
- Create: `Sources/PetsCore/Usage/CodexUsageSource.swift`
- Create: `Tests/PetsCoreTests/Usage/BuildCLIUsageSourceTests.swift`
- Create: `Tests/PetsCoreTests/Usage/CodexUsageSourceTests.swift`

- [ ] Write parser tests using inline JSON/JSONL fixtures, including null token events, multiple cumulative events in one session, a session crossing the period boundary, malformed output, and weekly period IDs.
- [ ] Run `swift test --filter 'BuildCLIUsageSourceTests|CodexUsageSourceTests'` and confirm failure.
- [ ] Define `PetUsageSource` with stable ID, display name, and synchronous throwing `read()` suitable for a detached utility task.
- [ ] Implement the build-cli parser and command runner with executable discovery at the current user path and normal PATH locations.
- [ ] Implement Codex file scanning for `~/.codex/sessions` and `~/.codex/archived_sessions`; count each session's cumulative delta inside the current Monday-based week.
- [ ] Rerun focused tests and confirm they pass.

### Task 4: Persist and orchestrate collection state

**Files:**
- Create: `Sources/Pets/PetCollectionPersistence.swift`
- Modify: `Sources/Pets/PetStore.swift`
- Modify: `Sources/Pets/PetSettingsPersistence.swift` only if shared normalization support is needed
- Create: `Tests/PetsCoreTests/Pets/PetCollectionIntegrationSourceTests.swift`

- [ ] Add source-level regression tests for collection persistence, reward refresh, ownership gating, and reveal state.
- [ ] Run the focused source tests and confirm they fail.
- [ ] Load collection state after pet instances, normalize starter plus configured IDs, and publish collection/status/reveal properties.
- [ ] Start one reward refresh at app launch and repeat every 15 minutes independently of the five-second harness session scanner.
- [ ] Run usage readers off the main actor, apply successful readings individually, preserve errors per source, and persist every state mutation.
- [ ] Add `refreshRewardUsage()`, `upgradeKeys(from:)`, `openChest(_:)`, `dismissUnlockedPet()`, `addPet(petID:)`, and `isPetOwned(_:)`.
- [ ] Reject locked IDs in `updateSelectedPetID(_:)` and create new instances using the selected definition's defaults.
- [ ] Rerun focused tests and confirm they pass.

### Task 5: Generate and package production chest artwork

**Files:**
- Create: `Sources/PetsCore/Resources/PetArt/LootChests/common.png`
- Create: `Sources/PetsCore/Resources/PetArt/LootChests/rare.png`
- Create: `Sources/PetsCore/Resources/PetArt/LootChests/legendary.png`
- Modify: `Sources/PetsCore/Pets/PetArtResourceLocator.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

- [ ] Generate one square asset per rarity using the approved contact sheet only as style reference and a chroma-key background for alpha extraction.
- [ ] Remove the chroma background with the bundled imagegen script and validate transparent corners, clean edges, and useful subject coverage.
- [ ] Add a typed `PetChestArtResource` lookup in `PetArtResourceLocator`.
- [ ] Write and run resource tests proving all three PNGs are found through `Bundle.module`.
- [ ] Inspect all three final assets visually at original detail.

### Task 6: Build the native Collection Hub and ownership gates

**Files:**
- Create: `Sources/Pets/PetCollectionViews.swift`
- Modify: `Sources/Pets/PetSettingsViews.swift`
- Create: `Tests/PetsCoreTests/Pets/PetCollectionViewSourceTests.swift`
- Preserve: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

- [ ] Write failing source tests for the Collection toolbar tab, progress header, three key balances, 5:1 upgrade controls, source rows, three chest tiers, collection grid, reveal sheet, refresh control, and locked sprite-picker cards.
- [ ] Add `.collection` to `PetSettingsTab` and route it to `PetCollectionView` without altering General or Pets roots.
- [ ] Build a scrolling hub with semantic colors, system symbols, generated chest images, explicit disabled reasons, and accessible progress/status labels.
- [ ] Present a native unlock sheet from store reveal state and wire **Add to Desktop**.
- [ ] Update the sprite picker to show locked cards but only allow owned selections.
- [ ] Keep the existing user's `PetSidebarRow` simplification untouched.
- [ ] Run focused source tests and `swift build`.

### Task 7: Verify behavior and visual fidelity in the packaged app

**Files:**
- Create: `design-qa.md`
- Create: local QA screenshots under `.artifacts/pet-collection-qa/`

- [ ] Run `./scripts/check.sh`.
- [ ] Run the real local usage readers and confirm the first refresh computes a nonnegative balance without double counting on a second refresh.
- [ ] Run `./scripts/run_app.sh --verify` and open the singleton Pets Configuration window.
- [ ] Exercise Collection navigation, refresh, disabled/enabled chest states, reveal, Add to Desktop, and sprite ownership gating.
- [ ] Capture the approved reference and native implementation at the same 900×620 content size.
- [ ] Place both images together in one comparison input, inspect visible hierarchy/spacing/cropping/type/color mismatches, and iterate until acceptable.
- [ ] Write `design-qa.md` with `final result: passed` only after the combined comparison passes.
- [ ] Run `git diff --check`, inspect `git status`, and confirm unrelated dirty files remain preserved.
