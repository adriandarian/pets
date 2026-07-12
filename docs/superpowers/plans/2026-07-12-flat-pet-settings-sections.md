# Flat Pet Settings Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the three settings-card backgrounds and replace them with flat, Apple-style section hierarchy.

**Architecture:** Keep the existing configuration window, sidebar, detail scroll view, controls, and data bindings. Add one reusable `FlatSettingsSection` layout component, replace the three `GroupBox` wrappers, and separate sections with native dividers.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Swift Package Manager.

## Global Constraints

- Preserve `ScrollView(.vertical, showsIndicators: false)` and vertical scrolling.
- Preserve the sprite preview's framed grid canvas.
- Preserve every control, binding, action, label, Light/Dark behavior, and system accent color.
- Do not add custom section backgrounds, shadows, strokes, or rounded rectangles.

---

### Task 1: Flatten the pet settings sections

**Files:**
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift:178-220`
- Modify: `Sources/Pets/PetSettingsViews.swift:203-530`

**Interfaces:**
- Consumes: `PetDetailsSection`, `PetAppearanceSection`, `PetBehaviorSection`, and their existing bindings and actions.
- Produces: `FlatSettingsSection<Content: View>` and three background-free section compositions.

- [ ] **Step 1: Write the failing source-contract assertions**

Add these assertions to `petSettingsUseNativeAdaptiveSidebarAndDetailLayout()`:

```swift
#expect(source.contains("private struct FlatSettingsSection<Content: View>: View"))
#expect(source.contains("FlatSettingsSection(\"Pet Details\")"))
#expect(source.contains("FlatSettingsSection(\"Appearance\")"))
#expect(source.contains("FlatSettingsSection(\"Behavior\")"))
#expect(!source.contains("GroupBox {"))
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: `petSettingsUseNativeAdaptiveSidebarAndDetailLayout()` fails because the three sections still use `GroupBox` and `FlatSettingsSection` does not exist.

- [ ] **Step 3: Implement the flat section component**

Add this component before `PetDetailsSection`:

```swift
private struct FlatSettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Replace the `PetDetailsSection` body with:

```swift
var body: some View {
    FlatSettingsSection("Pet Details") {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                Text("Name")
                    .foregroundStyle(.secondary)

                TextField("", text: nameBinding)
                    .accessibilityLabel("Name")
            }

            GridRow {
                Text("Style")
                    .foregroundStyle(.secondary)

                Picker("Pixelation", selection: pixelationBinding) {
                    ForEach(PetSpritePixelation.allCases, id: \.self) { pixelation in
                        Text(pixelation.displayName)
                            .tag(pixelation)
                            .disabled(pixelation > PetCatalog.maximumPixelation(for: selectedPet.petID))
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }

            GridRow {
                Text("Context")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Slider(
                        value: contextLineCountSliderBinding,
                        in: contextLineCountSliderRange,
                        step: 1
                    )

                    Text("\(selectedPet.sessionContextLineCount)")
                        .monospacedDigit()
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Replace the `PetAppearanceSection` body with:

```swift
var body: some View {
    FlatSettingsSection("Appearance") {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(PetCatalog.displayName(for: pet.petID))
                    .font(.body.weight(.medium))

                Text(spriteDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Change Sprite...") {
                changeSprite()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Replace the `PetBehaviorSection` body with:

```swift
var body: some View {
    FlatSettingsSection("Behavior") {
        VStack(spacing: 0) {
            SettingSwitchRow("Hover bounce", isOn: animationBinding(\.isHoverBounceEnabled))

            Divider()

            SettingSwitchRow("Idle motion", isOn: animationBinding(\.isIdleMotionEnabled))

            Divider()

            SettingSwitchRow("Status moods", isOn: animationBinding(\.areStatusMoodsEnabled))
        }
    }
}
```

In `PetDetailPane`, change the settings sequence to:

```swift
PetDetailsSection(store: store)

Divider()

PetAppearanceSection(
    pet: pet,
    changeSprite: changeSprite
)

Divider()

PetBehaviorSection(store: store)
```

Add `.padding(.vertical, 6)` to `SettingSwitchRow` so each flat switch row keeps native breathing room without a container background.

- [ ] **Step 4: Run focused and full verification**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
./scripts/check.sh
```

Expected: both commands exit successfully with zero failures.

- [ ] **Step 5: Verify the packaged configuration window**

Run:

```bash
./scripts/run_app.sh --verify
```

Open Configure and confirm Pet Details, Appearance, and Behavior sit directly on the detail background with no rounded section containers. Confirm the sprite preview remains framed and no scrollbar is visible.

- [ ] **Step 6: Commit the refinement**

```bash
git add Sources/Pets/PetSettingsViews.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift docs/superpowers/specs/2026-07-12-flat-pet-settings-sections-design.md docs/superpowers/plans/2026-07-12-flat-pet-settings-sections.md
git commit -m "refactor: flatten pet settings sections"
```
