# Cloud Ambient Effects Design

**Date:** 2026-07-13

**Status:** Approved for implementation

## Summary

Nimbus, Cirrus, and Snow Cloud will gain independently animated ambient details while retaining their existing generated body and blink loops. The new effects are deterministic SwiftUI-rendered voxel shapes inside the pet composition, so they remain crisp under the existing pixelation pipeline and move relative to the pet instead of being flattened into each PNG frame.

The existing **Idle Motion** setting remains the only control. Turning it off freezes frame playback, body motion, and ambient effects. Active completion or error reactions also freeze the ambient loop, matching current reaction behavior.

## Approaches Considered

### 1. Deterministic runtime voxel effects — selected

Draw small snow, rain, lightning, and wind shapes in SwiftUI from pure time samples. This provides continuous directional movement, keeps effect timing testable, and does not require editing 24 generated body frames.

### 2. Separate generated effect sprite sheets

Generate transparent weather-only animation sheets and play them over the body. This can provide richer artwork, but it depends on image-generation access, introduces another asset manifest, and still limits motion to authored frames.

### 3. Regenerate the existing body frames

Edit every body frame to move its weather details more aggressively. This preserves one-layer rendering but repeats the current architectural limitation: weather stays flattened into the body, long holds remain visible, and crossfades ghost small details instead of moving them continuously.

## Architecture

### Core motion model

`PetsCore` will define:

- `PetAmbientEffectKind`: `.none`, `.storm`, `.wind`, and `.snow`.
- `PetAmbientParticleSample`: normalized position, opacity, scale, stretch, and rotation for one independently rendered detail.
- `PetAmbientEffectSample`: the particles for a moment plus lightning intensity.
- A deterministic sampler driven by elapsed time, pet phase offset, and an enabled flag.

The sampler contains no SwiftUI types. Tests can prove wrapping, direction, phase staggering, lightning cadence, and disabled-state freezing without rendering a view.

### Definition metadata

`PetDefinition` will expose an `ambientEffect` value with `.none` as the default. Nimbus selects `.storm`, Cirrus selects `.wind`, and Snow Cloud selects `.snow`. Cumulus and Lenticular remain `.none`.

### SwiftUI composition

`AssetPetSprite` continues to own one `TimelineView`. For every timeline tick it samples body playback, whole-pet motion, and ambient motion from the same elapsed time and stable per-instance phase.

Inside the existing 128-unit geometry:

1. Render the grounding shadow.
2. Render background ambient details where appropriate.
3. Render the blended generated pet body.
4. Render foreground ambient details.
5. Apply the existing whole-pet scale, anchor, motion, reaction treatment, and final pixelation.

This order keeps the effects attached to the moving pet while preserving their independent local travel.

## Species Behavior

### Snow Cloud

- Six staggered voxel snowflakes fall below and around the cloud.
- Each flake wraps to the top of its local travel lane after reaching the bottom.
- Small horizontal drift, scale variation, and rotation keep the fall from looking synchronized.
- Static snowflakes already present in the generated body remain part of its identity; the moving flakes read as newly shed snow.

### Nimbus

- Seven blue voxel raindrops fall at staggered phases beneath the cloud and wrap continuously.
- A gold lightning overlay aligns with the existing central bolt.
- The overlay remains invisible most of the cycle, then produces a short double pulse rather than a constant glow.
- The existing baked rain and bolt remain the neutral pose; moving drops and the pulse provide the missing activity.

### Cirrus

- Four pale wind ribbons travel horizontally from left to right behind and alongside the cloud.
- Ribbons use different lengths, vertical lanes, and speeds.
- Opacity eases near the left and right edges so wrapping is not abrupt.
- The existing tendrils continue their subtle authored curl while the ribbons make airflow direction readable.

## Image Generation Decision

No new production bitmap is required for this upgrade. The image-generation environment does not currently expose `OPENAI_API_KEY`, and code-native voxel geometry better satisfies the continuous-motion requirement than another flattened asset sequence. Existing generated pet artwork remains unchanged.

## Performance and Failure Behavior

- The effect sampler uses fixed-size arrays and simple arithmetic.
- SwiftUI renders a small bounded number of shapes per pet.
- The existing 30 Hz timeline and pixelation snapshot loop remain unchanged.
- Unknown pets and definitions without metadata render `.none` and cannot fail.
- Disabled motion returns a stable canonical sample instead of hiding effects.

## Testing and Acceptance

Core tests will prove:

- Catalog definitions select the correct ambient effect.
- Snow moves downward and wraps.
- Storm rain moves downward with staggered lanes.
- Lightning is normally off and reaches a visible pulse.
- Wind moves horizontally and fades near wrap boundaries.
- Identical time and phase inputs are deterministic.
- Disabled motion returns the same frozen sample at every elapsed time.

Source-level renderer tests will prove that the ambient view is composed around the blended body and receives the Idle Motion gate. Final verification requires focused tests, the full repository check, a rebuilt app bundle, and visual inspection of the running app or captured render at actual overlay scale.
