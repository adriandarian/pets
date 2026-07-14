# Pet Loot Box Collection Design

**Date:** 2026-07-13
**Status:** Approved direction A — Collection Hub

## Goal

Add a durable pet-reward loop to the native Pets settings app. Combined token usage earns keys, keys open rarity-specific chests, and each chest unlocks a pet in a family-aware collection browser.

The first release should make the loop real without introducing duplicate rewards, trading, shops, paid currency, or a large live-ops economy.

## Product Rules

- Every account starts with Cumulus unlocked.
- Any pet already configured before this feature ships is grandfathered into the owned collection.
- Every **500,000,000 newly observed tokens** across supported providers awards one shared Pet Key.
- Token progress carries across refreshes and provider periods. Only newly observed usage is added, so rereading the same provider total cannot mint keys twice.
- The first successful scan counts the current provider-period total. This lets an existing user receive the progress they already generated during that period.
- Provider failures are isolated: one failed source cannot erase progress or block successful sources.
- Keys are a single currency used by all chest tiers.
- Chest costs are:
  - Common: 1 key
  - Rare: 2 keys
  - Legendary: 4 keys
- A chest selects an unowned pet from the chosen rarity. If the rarity is exhausted, that chest is disabled and no keys are spent.
- Duplicate pet rewards are excluded in this release.
- Unlocking a pet adds it to the collection; it does not automatically create a desktop pet.
- Collection is browse-only. Creating and managing desktop pet instances remains exclusively in the Pets tab.

## Initial Catalog Rarities

| Pet | Rarity | Initial state |
| --- | --- | --- |
| Cumulus | Common | Starter, always owned |
| Nimbus | Common | Chest reward |
| Cirrus | Rare | Chest reward |
| Lenticular | Rare | Chest reward |
| Snow | Legendary | Chest reward |

Rarity belongs to each `PetDefinition`, not to the view. Future pets become reward-eligible by declaring their rarity in the catalog.

## Supported Usage Sources

The initial release counts sources that expose trustworthy local token totals:

1. **Claude Code** via `build-cli usage --period weekly --format json --no-cache --no-update-check`.
2. **Codex** via local session JSONL files. For each session, the scanner uses the latest cumulative `total_token_usage.total_tokens` observed inside the requested period, which prevents repeated token-count events from being summed.

Copilot and Antigravity remain future adapters because their installed CLIs do not currently expose a reliable account-wide token total. The reward ledger is provider-neutral so they can be added without changing chest or collection logic.

## Collection Hub UX

Collection is a third centered segment beside General and Pets in the existing settings toolbar. The 900×620 native settings window and adaptive macOS materials remain unchanged.

The Collection screen is a vertically scrolling hub with four sections:

1. **Progress header**
   - Key balance is the strongest value.
   - A progress bar shows carried token progress toward the next 500M key.
   - Supporting copy shows exact progress and how many tokens remain.
   - A refresh button reruns usage collection without blocking the rest of Settings.

2. **Usage sources**
   - Compact source rows show Claude and Codex totals and their last scan state.
   - A source error is shown inline in secondary/destructive text and does not replace the whole screen.

3. **Chest shelf**
   - Three equal tiles use real generated chest artwork for Common, Rare, and Legendary.
   - Each tile shows rarity, key cost, remaining eligible pets, and an Open button.
   - Disabled reasons are explicit: not enough keys, all collected, or refresh in progress.

4. **Family collection browser**
   - A segmented family picker is sourced directly from `PetCatalog.builtInCategories` and remains visible even while Clouds is the only family.
   - Selecting a family filters the compact pet grid to that category and updates family progress such as **3 of 5 obtained**.
   - Obtained pets render in full color with a subtle checkmark and the text **Obtained**.
   - Missing pets remain identifiable through a subdued sprite, system lock icon, and explicit text such as **Missing · Rare**.
   - Collection cards have no buttons or actions. They communicate ownership and rarity without creating desktop pet instances.
   - Future catalog families appear automatically as new picker segments without changing Collection view structure.

Opening a chest presents a native reveal sheet with the unlocked pet sprite, name, rarity, and a single **Done** action. Adding the unlocked species to the desktop happens later through the Pets tab.

## Visual Direction

The approved Collection Hub mockup establishes the hierarchy: progress first, a three-chest shelf in the middle, and the collection below. The implementation adapts that hierarchy to the app's existing native design language:

- semantic system backgrounds instead of a fixed dark-green page skin;
- system accent color for progress and primary actions;
- existing `PetSprite` rendering for pets;
- SF Symbols for keys, locks, refresh, and status icons;
- individual generated transparent PNG chest assets sized for their actual tile slots.

No emoji, placeholder boxes, cropped contact sheets, custom-drawn fake icons, or casino/purchase language are used.

## State and Persistence

`PetCollectionState` is a versionable Codable value persisted separately from pet-instance settings. It owns:

- owned pet IDs;
- available key count;
- carried token remainder below 500M;
- per-provider checkpoints keyed by provider and period;
- last successful provider readings for display.

On load, state normalization always unions Cumulus and all configured pet IDs into ownership. Unknown catalog IDs are retained in persistence for forward compatibility but ignored by current UI selection.

The reward refresh runs once at app start and then on a slower cadence than session scanning. Manual refresh is always available from Collection.

The selected family is ephemeral view state. On appearance it uses the first catalog family; if a selected family disappears during development, the view falls back to the first available category. Family browsing does not mutate collection or pet-instance persistence.

## Error Handling

- Corrupt collection persistence falls back to normalized starter ownership and reports a collection-specific status without destroying pet configuration.
- A command that is unavailable or returns malformed data produces an error on that provider row.
- Token totals that move backward never subtract progress or keys.
- Opening a chest is an atomic state transition: eligibility and key balance are validated before mutation, then ownership and key spend are persisted together.
- A missing or obsolete selected family ID falls back to the first registered catalog family instead of producing an empty or broken collection grid.

## Accessibility

- Every chest image has a text accessibility label.
- Progress exposes a combined value such as “442 million of 500 million tokens.”
- Locked state and disabled reasons are present in text, not color alone.
- Obtained and missing states use text and symbols in addition to color and saturation.
- The reveal's Done action is keyboard reachable and uses a standard button style.
- The family picker has a descriptive **Pet family** label for accessibility even when its visible style is segmented.
- The layout remains legible in light and dark appearance through semantic colors.

## Scope Boundaries

This release does not include duplicate conversion, pity systems, limited-time boxes, purchases, key rarity, pet leveling, trading, cloud sync, social sharing, or remote usage APIs.

## Acceptance Criteria

- A clean install owns Cumulus.
- Existing configured pets are owned after migration.
- Reapplying the same usage readings awards nothing twice.
- 500M carried tokens award exactly one key and retain the correct remainder.
- A chest never returns an owned pet and never spends keys when it cannot open.
- Only owned pets can be selected or added to the desktop from the Pets tab.
- Collection displays each registered family through the family picker and filters its grid to the selected family.
- Collection cards show explicit Obtained or Missing state and contain no Add actions.
- The Collection tab, manual refresh, all three chest controls, browse-only reveal sheet, and family browser work in the packaged macOS app.
- Generated chest resources load from `PetsCore` in the packaged app.
- Focused tests, the full test suite, build, packaged launch, and image-to-code visual QA all pass.
