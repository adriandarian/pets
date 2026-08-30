# Pet configuration and collection navigation design QA

## Evidence

- Source visual truth: `.artifacts/pet-settings-no-scroll/source.png`.
- Native implementation: `.artifacts/pet-settings-no-scroll/implementation.jpeg`.
- Combined comparison: `.artifacts/pet-settings-no-scroll/comparison-source-vs-implementation.png`.
- Viewport: 900 x 672 native Pets Dev window, corresponding to the 900 x 620 content minimum plus macOS toolbar.
- Implementation state: persisted isolated Pets Dev state with Nova, two preview lines, and Chunky Pixels unavailable for that Whiskerkin sprite. The source visual uses Nimbus and one preview line.

## Required fidelity surfaces

- Navigation: Pets, Chests, and Collection are separate top-level destinations with full icon-and-text labels and a pink selection underline, with no shared rounded toolbar container.
- Configuration structure: the pet editor has no vertical scroll surface at the default size.
- Secondary navigation: Details, Tracking, and Look & Motion use bare icons at the default width; only the selected icon and short underline receive accent color.
- Adaptive behavior: `ViewThatFits(in: .horizontal)` swaps those bare icons for icon-and-text labels when the settings pane has enough width.
- Pet actions: the header contains one ellipsis menu; Respawn, Hide or Show, Duplicate, and Delete are inside it.
- Pet selection: Change Pet is a compact paw-and-arrows control inside the preview.
- Style: styles are plain inline text choices with a selected underline inside a horizontal overflow container, so future styles do not force a dropdown or widen the pane.
- Session preview: the ambiguous Context label is replaced by Session preview, helper copy, a discrete 1 through 4 slider, ticks, and a trailing singular or plural line count.
- Collection separation: the chest screen contains reward progress and chest opening only; the dedicated Collection screen owns family browsing and the pet grid.

## Comparison history

1. Pass 1 confirmed the native two-column structure, bare section icons, in-preview Change Pet control, discrete slider, and no vertical configuration scroll. It found three platform-rendered P2 issues: toolbar labels collapsed to icons, Chunky Pixels was clipped, and the ellipsis menu showed an unwanted indicator.
2. Pass 2 forced title-and-icon toolbar labels, hid the menu indicator, and tightened the style strip. It found one remaining P2 truncation: Collection and Chunky Pixels still compressed in the native toolbar and settings row.
3. Pass 3 fixed intrinsic toolbar sizing and text-strip metrics. All destination labels and all four current style names are visible at 900 pixels wide.
4. Pass 4 matched the selected horizontal proportions: a 260-point preview, source-aligned body inset, and a wider settings pane. The final side-by-side comparison has no remaining P0, P1, or P2 implementation issue. Pet species, visibility, slider value, and disabled style availability are persisted content-state differences.
5. Pass 5 removed the macOS 26 shared Liquid Glass toolbar background with `sharedBackgroundVisibility(.hidden)`. The signed Pets Dev render confirms the destination icons, labels, and underline now sit directly on the toolbar with no containing box.

## Verification

- The accessibility tree exposes all three top destinations, all three secondary configuration sections, Change Pet, the Name field, all four style options, Session preview, its 1 through 4 slider, and the trailing line count.
- The isolated signed `dist/Pets Dev.app` bundle launches successfully without replacing the normal Pets app.
- The affected source-contract suites pass 42 tests across three suites.
- The toolbar-background regression suite passes 27 tests and the signed app was visually rechecked on macOS 26.
- The canonical full project check passes 271 tests across 32 suites and a clean debug build.

final result: passed
