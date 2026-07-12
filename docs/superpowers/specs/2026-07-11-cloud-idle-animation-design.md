# Cloud Idle Animation Design

**Date:** 2026-07-11

**Status:** Approved in conversation; pending written-spec review

## Summary

All five built-in cloud pets will receive species-specific idle animation that combines generated multi-frame artwork with smooth code-driven ambient motion. Each pet will use an eight-frame, approximately 5.56-second transparent PNG loop for breathing, pose changes, and a restrained facial micro-expression. Runtime transforms will add continuous float, bob, sway, and responsive shadow movement between those generated poses.

The system will preserve the current pet identities and asset renderer. New frames will be created as edits of each existing canonical idle image, not as unrelated regenerations. Frame playback will crossfade between neighboring images, multiple pet instances will receive stable phase offsets so they do not move in sync, and the existing Idle Motion setting will freeze both image playback and transforms.

## Goals

- Make idle cloud pets visibly but gently alive at the actual overlay size.
- Give Cumulus, Nimbus, Cirrus, Lenticular, and Snow Cloud distinct motion personalities.
- Add eight-frame generated idle loops for all five clouds, for 40 production frames total.
- Reuse the existing five `frame-000.png` images as canonical neutral frames and add 35 edited frames.
- Preserve camera, voxel scale, lighting, palette, face identity, subject scale, and canvas anchor across each loop.
- Blend generated frames smoothly while retaining quick, readable blink timing.
- Add continuous ambient movement and responsive grounding shadows around frame transitions.
- Desynchronize multiple pet instances deterministically.
- Keep completion and error reactions visually distinct by freezing idle keyframes while reaction motion is active.
- Keep the implementation harness-neutral, asset-pack-driven, and compatible with future pet definitions.

## Non-Goals

- Adding sounds.
- Adding new settings or changing the meaning of the Idle Motion setting.
- Creating new busy, waiting, excited, sleeping, completion, or error artwork.
- Changing session-state detection or reaction timing.
- User-authored animation packs or an animation editor.
- Physics simulation, particles, or procedural weather.
- Replacing the existing canonical cloud identities.

## Art Direction

Every new image is an edit of its species' existing `frame-000.png`. Each frame must retain:

- The same 512x512 transparent canvas.
- The same three-quarter camera and perspective.
- The same voxel dimensions, materials, lighting direction, and pastel-white palette.
- The same face placement, eye style, blush, mouth scale, and arm construction.
- The same subject scale and floor anchor within the canvas.
- Transparent corners and no baked floor, cast shadow, text, border, or background.

Pose changes should be small enough that the character reads as one continuous model. Generated frames may move expressive secondary elements—raindrops, lightning, wind tendrils, layered bands, icicles, and snowflakes—but may not add or remove defining anatomy.

## Species Personalities

### Cumulus

- Rounded inhale and exhale through the upper cloud mass.
- Hands lift slightly at the breathing peak.
- Gentle two-eye blink.
- Tiny smile softens at the peak, then returns to neutral.
- Runtime motion: slow breathe plus a small vertical float.

### Nimbus

- Heavier, lower hover with restrained vertical travel.
- Raindrops shift slightly as if suspended beneath the body.
- Lightning receives one subtle brightness variation without becoming a flash effect.
- Slow, determined blink; mouth remains composed.
- Runtime motion: weighted bob with a denser shadow response.

### Cirrus

- Long wind tendrils curl and relax without changing their count.
- Body drifts slightly sideways through the breathing cycle.
- One playful wink instead of a symmetrical blink.
- Runtime motion: lateral drift and gentle sway.

### Lenticular

- Upper and lower bands shift subtly in opposite directions while preserving the saucer silhouette.
- Calm symmetrical blink.
- Very controlled vertical hover.
- Runtime motion: restrained breathe/float with minimal rotation.

### Snow Cloud

- Icicles sway by a few pixels while retaining count, color, and attachment points.
- Snowflakes shift and shimmer through pose/brightness variation without particle effects.
- Cozy symmetrical blink and a slightly brighter peak expression.
- Runtime motion: buoyant breathe and float.

## Frame Sequence and Timing

Every species uses the same filenames and base timing so tooling and validation remain uniform:

| Frame | Pose | Duration | End Blend |
| --- | --- | ---: | ---: |
| `frame-000.png` | Canonical neutral hold | 2.00 s | 0.22 s |
| `frame-001.png` | Early inhale / gesture begins | 0.65 s | 0.18 s |
| `frame-002.png` | Lifted breathing peak | 0.55 s | 0.20 s |
| `frame-003.png` | Exhale / gesture relaxes | 0.65 s | 0.18 s |
| `frame-004.png` | Secondary neutral hold | 1.45 s | 0.12 s |
| `frame-005.png` | Half blink or half wink | 0.08 s | 0.04 s |
| `frame-006.png` | Closed blink or wink | 0.10 s | 0.04 s |
| `frame-007.png` | Reopening eyes | 0.08 s | 0.04 s |

Total loop duration is 5.56 seconds. The final frame blends back to `frame-000.png` when the animation loops.

Durations are authored per frame. A frame displays alone until the final `blendDuration` portion of its duration, then crossfades to the next frame. Blink transitions remain quick because their blend windows are 0.04 seconds. One-frame animations continue to render without blending.

## Playback Model

### Frame Sampling

`PetAnimationFrame` will gain a nonnegative `blendDuration` that must not exceed its `duration`. The default is zero so all current one-frame status animations preserve their existing behavior.

`PetAnimation` will expose a playback sample containing:

- Primary frame index.
- Optional next frame index.
- Next-frame opacity from `0...1`.

For looping animations, the last frame may blend to the first. For one-shot animations, the final frame remains fully visible. Existing `frameIndex(at:)` behavior remains available and consistent with the primary sample index.

The SwiftUI renderer will load the primary and optional secondary images into a transparent `ZStack`, apply the opacity blend, and then apply ambient motion to the combined image. The generated grounding shadow remains a separate sibling underneath the blended image.

### Stable Phase Offsets

`PetVisualContext` will gain a normalized animation phase offset with a default of zero. Live overlays derive it deterministically from the persisted `PetInstance.ID`; static catalog previews may continue using zero.

The renderer converts the normalized offset to a duration within the selected animation and adds it to elapsed time. Two instances with the same sprite therefore do not blink, float, or change frames in lockstep, while one instance retains a stable offset across launches.

The identifier-to-phase function must use a stable deterministic algorithm rather than Swift's randomized `hashValue`.

### Idle Motion Setting

When `isIdleMotionEnabled` is false:

- Frame playback freezes on `frame-000.png`.
- Frame crossfading stops.
- Code-driven transforms stop.
- Shadow movement stops.
- The pet retains its normal static presentation and current visual-state selection.

### Reaction Interaction

Completion and error remain higher-priority visual states. Because their optional artwork currently falls back to the idle pack, the renderer must freeze fallback keyframe playback on `frame-000.png` while a reaction is active. `PetReactionVisualModifier` remains responsible for reaction movement and color treatment. Ambient idle transforms and reaction transforms must not stack.

When the reaction clears, the pet resumes its phase-offset idle loop at the current global time rather than replaying from the beginning.

## Ambient Motion and Shadow Response

The existing motion presets remain the definition-level routing vocabulary, but their output will be expressed as a testable motion sample rather than private view-only math. A sample contains image scale, x/y offset, rotation, shadow scale, and shadow-opacity multiplier.

At the 132-point sprite canvas before the overlay's outer scale:

- `breathe`: scale varies by approximately +/-2.2%, with vertical travel from 0 to about 3 points upward.
- `bob`: weighted vertical travel spans approximately 5 points with only subtle scale change.
- `sway`: rotation spans approximately +/-3 degrees with up to 1.5 points of lateral drift.
- `pulse`: retains its more energetic reaction/hover character and is not used as the default idle profile.
- `none`: returns identity transforms and an unchanged shadow.

As the subject rises, the shadow contracts slightly and loses opacity. As it settles, the shadow widens and darkens. The response must remain subtle enough to read as grounding rather than a second animation.

The overlay's existing 0.72 outer scale is part of acceptance: final visible motion should remain readable after that scale is applied, unlike the current sub-pixel breathe effect.

## Asset Generation Workflow

For each species:

1. Use the current `frame-000.png` as the required image-editing reference.
2. Generate frames `001...007` individually, repeating the species identity, camera, canvas, anchor, palette, lighting, and allowed pose delta in every edit instruction.
3. Normalize output mechanically to a 512x512 transparent PNG without redrawing or inventing content.
4. Reject outputs with opaque corners, background residue, changed camera, face drift, extra/missing anatomy, inconsistent voxel scale, or altered lighting direction.
5. Build an eight-frame contact sheet at actual relative scale.
6. Compare silhouette, face centroid, subject bounds, secondary-element count, and loop continuity.
7. Regenerate rejected frames rather than repairing identity drift with manual paint-over.
8. Keep only accepted production PNGs under the species' `idle/` directory.

Generation order is canonical body poses (`001...004`) first, then blink/wink poses (`005...007`). Later edits may use an accepted neighboring pose as an additional reference when that improves continuity, while the canonical `frame-000.png` remains the primary identity reference.

## Asset Validation

Automated resource validation will require every registered cloud idle pack to contain exactly `frame-000...frame-007` and will verify:

- Width and height are 512 pixels.
- An alpha channel exists.
- All four corner pixels are fully transparent.
- Subject bounds remain within the canvas.
- Subject-bound center stays within 8 pixels of the canonical center.
- Subject-bound width and height stay within 8% of the canonical bounds unless the approved species gesture intentionally moves a secondary element.

Contact-sheet review remains the authority for face identity, voxel continuity, expression quality, and allowed secondary-element motion because those cannot be reliably reduced to pixel-bound thresholds.

## File and Component Boundaries

- `PetAnimation.swift`: frame blend metadata and deterministic playback sampling.
- A focused `PetMotion` core file: testable motion and shadow samples plus stable phase derivation.
- `PetVisualStateResolver.swift`: carries the defaulted normalized phase value without changing state priority.
- `CloudPetDefinitions.swift`: declares all eight idle frames and exact timing for each species.
- `PetOverlayView.swift`: supplies stable per-instance phase to live sprites.
- `PetSprites.swift`: blends neighboring frame images, applies one ambient transform to the blended result, freezes idle playback during reactions, and applies final pixelation outside the asset renderer.
- `Resources/PetArt/<species>/idle/`: eight accepted PNG frames per species.

No session scanner, harness, persistence schema, settings UI, or reaction-coordination file needs to change.

## Error Handling and Fallbacks

- Invalid animation metadata fails `PetAnimation` initialization.
- A missing generated frame continues to show the existing visible missing-art placeholder rather than crashing.
- Image-cache lookup remains keyed by resolved frame URL.
- Phase derivation never uses unstable process-random hashing.
- Disabled idle motion provides a deterministic static fallback.
- Reactions use the canonical idle frame when reaction-specific artwork is absent.

## Testing

Core tests will cover:

- Blend duration validation.
- Primary/secondary indices and opacity before, during, and after a blend window.
- Last-to-first blending for loops and final-frame holding for one-shot animations.
- Compatibility between `frameIndex(at:)` and the playback sample.
- Stable phase derivation for identical and distinct instance identifiers.
- Motion sample amplitudes at neutral, peak, and trough phases.
- Identity transforms for `.none` and when motion is disabled.
- Shadow contraction/opacity response when the subject rises.

Renderer/source integration tests will cover:

- Transparent two-image `ZStack` blending.
- One ambient motion modifier applied after image blending.
- Phase offset included in playback time.
- Frame zero and no ambient transform during reactions.
- Pixelation remaining outside the completed asset renderer.
- Live overlays providing per-instance phase while static previews retain the default.

Resource tests will cover all 40 production idle frames, dimensions, alpha, corners, exact filenames, and bound tolerances.

Verification will run focused animation, motion, resource, sprite, and overlay suites; then `./scripts/check.sh`; then `./scripts/run_app.sh --verify`. Visual verification will inspect all five contact sheets plus at least one smooth and one pixelated live pet. Multiple visible pet instances will be checked for desynchronized playback.

## Acceptance Criteria

- Every cloud shows visible, gentle idle movement at the actual overlay scale.
- Every cloud has eight identity-consistent idle frames with its approved species personality.
- Blends are smooth; blinks remain quick and readable.
- No pet gains an opaque rectangle, baked shadow, identity drift, or canvas jump.
- The runtime shadow reinforces lift and settling without distracting from the pet.
- Multiple instances do not animate in lockstep.
- Disabling Idle Motion produces a completely static canonical frame and shadow.
- Completion and error reactions do not double-stack idle transforms or keyframe playback.
- Existing busy, waiting, hover, sleeping, completion, error, settings, and pixelation behavior remains intact.
- All focused tests, full checks, build, packaged launch, resource validation, and visual review gates pass.
