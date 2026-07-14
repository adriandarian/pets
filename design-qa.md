# Pet Collection Hub design QA

## Evidence

- Source visual truth: `.artifacts/pet-collection-qa/source-direction-board.png`, approved direction A (Collection Hub).
- Rendered implementation: `.artifacts/pet-collection-qa/implementation-collection.png`, packaged `dist/Pets.app` in macOS dark mode.
- Combined comparison: `.artifacts/pet-collection-qa/comparison-source-vs-implementation.png`.
- Rendered viewport: 900 x 672 screenshot, containing the 900 x 620 Settings content window plus native window chrome.
- Compared state: live provider usage after opening one Common chest; 0 keys, 157,567,808 / 500,000,000 tokens toward the next key, and 3 / 5 pets discovered.

The full-view comparison is sufficient because the source direction is a single compact Collection Hub card and the implementation keeps every corresponding primary region legible in the same frame: progress, provider contributions, all three chest tiers, and the start of the collection grid. A separate focused-region comparison would duplicate the same evidence without exposing additional detail.

## Comparison findings

- The implementation preserves the approved hierarchy: Collection navigation, shared token progress, provider contribution rows, chest choices, and owned-pet collection.
- Generated chest art replaces the source concept art with purpose-built Common, Rare, and Legendary assets sized for the native cards.
- The implementation uses the app's existing semantic dark-mode surfaces, native controls, spacing, typography, system icons, and pet artwork rather than copying the illustrative green presentation frame.
- The collection grid continues below the fold inside the existing Settings scroll surface. This is intentional native behavior, not clipping.
- Source and implementation numbers differ intentionally: the source is illustrative, while the implementation displays live local usage and persisted ownership.
- No P0, P1, or P2 visual defects remain. No actionable P3 defect was identified.

## Interaction verification

- Opened the Collection tab in the packaged app.
- Verified live Claude and Codex usage scanning and source status rows.
- Refreshed usage and observed progress increase without minting a duplicate key.
- Opened an enabled Common chest and revealed Nimbus.
- Added Nimbus to the desktop from the reveal sheet.
- Verified key spending, updated ownership, disabled chest reasons, and the 3 / 5 discovered count.
- Verified locked pets remain unavailable in the pet picker.

## Comparison history

1. Pass 1: source direction A and the packaged native implementation were placed together at readable scale. The hierarchy, assets, controls, and native layout matched the approved direction with no actionable P0, P1, or P2 mismatch.

final result: passed
