# Pet configuration and collection navigation design QA

## Evidence

- Source visual truth: `.artifacts/pet-settings-no-scroll/source.png`.
- Native implementation: `.artifacts/pet-settings-no-scroll/implementation.jpeg`.
- Combined comparison: `.artifacts/pet-settings-no-scroll/comparison-source-vs-implementation.png`.
- Focused expand-button source: `.artifacts/pet-settings-no-scroll/expand-button-source.png` (200 x 192).
- Focused expand-button implementation: `.artifacts/pet-settings-no-scroll/expand-button-implementation.png` (200 x 192 after 2x normalization).
- Focused comparison: `.artifacts/pet-settings-no-scroll/expand-button-comparison.png` (412 x 192, including the 12-point separator).
- Expanded-preview source: `.artifacts/pet-settings-no-scroll/expanded-preview-source.png` (1814 x 1356).
- Expanded-preview implementation: `.artifacts/pet-settings-no-scroll/expanded-preview-implementation.jpeg` (600 x 560 native active-sheet capture).
- Expanded-preview comparison: `.artifacts/pet-settings-no-scroll/expanded-preview-comparison.png` (1212 x 560).
- Viewport: 900 x 672 native Pets Dev window, corresponding to the 900 x 620 content minimum plus macOS toolbar.
- Density normalization: the 1487 x 1058 source was reduced to 900 x 640 and centered in a 900 x 672 comparison pane; the native implementation remained at its captured 900 x 672 size. The focused implementation crop was enlarged from 100 x 96 to 200 x 192 to match the user-supplied source crop. For the expanded state, the 1814 x 1356 source was normalized to the Computer Use capture's 600 x 448 app image and placed on the same 600 x 560 active-window canvas.
- Implementation state: persisted isolated Pets Dev state with Nova, two preview lines, and Chunky Pixels unavailable for that Whiskerkin sprite. The source visual uses Nimbus and one preview line.

## Required fidelity surfaces

- Navigation: Pets, Chests, and Collection are separate top-level destinations with full icon-and-text labels and a pink selection underline, with no shared rounded toolbar container.
- Configuration structure: the pet editor has no vertical scroll surface at the default size.
- Secondary navigation: Details, Tracking, and Look & Motion use bare icons at the default width; only the selected icon and short underline receive accent color.
- Adaptive behavior: `ViewThatFits(in: .horizontal)` swaps those bare icons for icon-and-text labels when the settings pane has enough width.
- Pet actions: the header contains one ellipsis menu; Respawn, Hide or Show, Duplicate, and Delete are inside it.
- Pet selection: Change Pet is a compact paw-and-arrows control inside the preview.
- Preview expansion: a circular diagonal-arrow control sits in the preview's bottom-right corner and opens a larger pet preview. Clicking outside the expanded surface or pressing Escape closes it.
- Style: styles are plain inline text choices with a selected underline inside a horizontal overflow container, so future styles do not force a dropdown or widen the pane.
- Session preview: the ambiguous Context label is replaced by Session preview, helper copy, a discrete 1 through 4 slider, ticks, and a trailing singular or plural line count.
- Collection separation: the chest screen contains reward progress and chest opening only; the dedicated Collection screen owns family browsing and the pet grid.

## Comparison history

1. Pass 1 confirmed the native two-column structure, bare section icons, in-preview Change Pet control, discrete slider, and no vertical configuration scroll. It found three platform-rendered P2 issues: toolbar labels collapsed to icons, Chunky Pixels was clipped, and the ellipsis menu showed an unwanted indicator.
2. Pass 2 forced title-and-icon toolbar labels, hid the menu indicator, and tightened the style strip. It found one remaining P2 truncation: Collection and Chunky Pixels still compressed in the native toolbar and settings row.
3. Pass 3 fixed intrinsic toolbar sizing and text-strip metrics. All destination labels and all four current style names are visible at 900 pixels wide.
4. Pass 4 matched the selected horizontal proportions: a 260-point preview, source-aligned body inset, and a wider settings pane. The final side-by-side comparison has no remaining P0, P1, or P2 implementation issue. Pet species, visibility, slider value, and disabled style availability are persisted content-state differences.
5. Pass 5 removed the macOS 26 shared Liquid Glass toolbar background with `sharedBackgroundVisibility(.hidden)`. The signed Pets Dev render confirms the destination icons, labels, and underline now sit directly on the toolbar with no containing box.
6. Pass 6 corrected the missing P1 preview action. The signed render and focused 200 x 192 comparison confirm the circular diagonal-arrow control now matches the source scale, treatment, and bottom-right inset. No P0, P1, or P2 mismatch remains.
7. Pass 7 preserves the native expanded-preview appearance while adding two dismissal paths: clicks delivered outside the sheet window dismiss and consume the event, and `onExitCommand` makes Escape collapse the preview explicitly. The expanded-state comparison shows no visual regression, and native verification confirms Escape returns to the normal configuration view.

## Verification

- The accessibility tree exposes all three top destinations, all three secondary configuration sections, Change Pet, Expand preview, the Name field, all four style options, Session preview, its 1 through 4 slider, and the trailing line count.
- Expand preview is wired to a larger live SwiftUI sheet with collapse-button, outside-click, and explicit Escape dismissal paths.
- Native UI verification opened the current expanded preview and confirmed that Escape collapses it immediately. The active-sheet automation surface cannot target the disabled parent window for an outside click, so that path is covered at the AppKit event-monitor boundary: a mouse-down delivered to another app window dismisses the sheet and consumes the first click.
- The isolated signed `dist/Pets Dev.app` bundle launches successfully without replacing the normal Pets app.
- The focused preview and toolbar regression suite passes 27 tests and the signed app was visually rechecked on macOS 26.
- The final collapsed-on-launch signed build compiles and relaunches cleanly.

final result: passed
