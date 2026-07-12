# Pet Reaction Moods Design

**Date:** 2026-07-11

**Status:** Approved for implementation planning

## Summary

Pets will gain a small event-driven reaction layer above its existing steady session moods. The first reactions are a four-second sunset celebration when an observed session enters the same `.idle` state that produces the green check on its session bubble, and a dark-cloud error mood that remains active exactly while `PetStore.lastError` is non-`nil`.

The reaction layer will be harness-neutral and shared by every visible pet. It will use runtime visual treatments so all current cloud pets react immediately, while extending the art-pack model with optional reaction artwork so individual pets can receive custom completion or error art later without changing event detection or overlay code.

## Goals

- Trigger completion from the same `.idle` status that renders the green check.
- Celebrate only a newly observed transition into `.idle`, never an already-idle session found on the initial scan.
- Show completion for four seconds and then restore the normal hover/status/sleeping state.
- Show the error reaction while `lastError` exists and clear it immediately when `lastError` clears.
- Give errors higher priority than completion and cancel an active completion when an error begins.
- Apply reactions consistently to every visible cloud pet and every sprite surface that receives live reaction context.
- Keep reaction detection independent of Claude-specific scanner types.
- Make future reactions and custom per-pet reaction artwork additive.

## Non-Goals

- New user-facing reaction settings.
- Sound effects, notifications, particles, rain, or lightning.
- Persisting active reactions across app launches.
- Replaying completion for sessions that were already idle when Pets started.
- Generating custom completion and error assets for every cloud in this change.
- Treating an unknown or removed session as completed.

## Reaction Semantics

### Completion

A session completes when an existing observed `HarnessSession` changes from any non-idle status to `.idle`. This is deliberately the same condition that changes its session indicator to the green check.

The first successful scan establishes a baseline and cannot produce a completion reaction. A session that first appears in a later scan already idle also does not produce a reaction because Pets did not observe its transition. Waiting-to-idle, busy-to-idle, and unknown-to-idle changes do produce completion after the baseline exists.

Completion begins when a qualifying transition is applied to the store and expires four seconds later. If another session completes during that interval, the expiry moves to four seconds after the newest completion. Completion is an in-memory app event; it is not saved to `UserDefaults`.

### Error

The error reaction is active whenever `PetStore.lastError` is non-`nil`, regardless of whether the error came from scanning, activation, reply sending, explicit error recording, or settings loading. It remains active until the error is cleared by the existing store behavior.

Beginning an error cancels any completion celebration. Clearing the error returns directly to the normal resolved visual state; it does not reveal a previous or paused completion reaction.

### Priority

Visual-state priority is:

1. Error reaction.
2. Completion reaction.
3. Hover excitement when enabled.
4. Existing status moods when enabled.
5. Existing idle or sleeping fallback.

The existing `Status moods` preference continues to control steady busy, waiting, idle, and sleeping selection. Error and completion reactions remain enabled because they are short app feedback rather than steady status styling. The existing idle-motion preference controls the code-driven pulse or lift: when motion is disabled, the sunset and dark color treatments still communicate the reaction without movement.

## Architecture

### Core Reaction Model

`PetsCore` will add a harness-neutral `PetReaction` enum:

```swift
public enum PetReaction: Equatable, Sendable {
    case completion
    case error
}
```

`PetVisualContext` will gain an optional `reaction`. The resolver will map reactions into two new `PetVisualState` values, `.completion` and `.error`, before applying hover or steady-state rules.

`PetArtPack` will gain optional `completion` and `error` animations. As with the existing optional states, a missing reaction animation falls directly back to the required idle animation. This preserves the current art-pack contract while allowing later custom assets to override the fallback.

### Transition Detection

`PetsCore` will add a focused value type that compares session snapshots by `HarnessSession.id`. It stores only the previous status map and whether a baseline has been established. Given a new session array, it reports whether one or more existing sessions newly entered `.idle`, then replaces its snapshot.

This detector will not own timers, Swift concurrency tasks, UI state, errors, or persistence. Its single responsibility is deterministic session-transition detection, which keeps it easy to unit test and reusable across future harnesses.

### Store Coordination

`PetStore` will own:

- The transition detector.
- A published optional current reaction.
- A cancellable completion-expiry task.
- The four-second completion duration.

Each successfully scanned session snapshot is passed through the detector before it replaces the current sessions. A qualifying completion sets `.completion` and schedules expiry. A newer completion cancels and replaces the previous expiry task.

All code paths that change `lastError` will pass through one small store helper. Setting an error cancels completion expiry and publishes `.error`. Clearing an error clears `.error`; normal session resolution then resumes. This helper prevents scanning, activation, reply, and explicit error paths from drifting apart.

Because reaction state belongs to `PetStore`, all visible pet instances respond together to the same app/session event. Individual overlay views do not create their own timers or independently infer transitions.

### Rendering

`PetOverlayView` will include `store.currentReaction` in the `PetVisualContext` passed to each `PetSprite`. Static settings and picker previews will continue to pass no reaction unless they are explicitly made live previews in a future change.

The asset renderer will first resolve the requested reaction animation. With the current cloud packs, that resolves to idle artwork. It will then apply a shared runtime treatment to the pet image while leaving the grounding shadow readable:

- Completion: a warm amber, coral, and pink sunset gradient masked to the cloud, a restrained warm glow, and a gentle pulse/lift when motion is enabled.
- Error: reduced saturation and brightness with a cool charcoal-blue tint and a subtle heavy/downward settle when motion is enabled.

Treatments must preserve the source PNG alpha and must not add a rectangular background. They are applied inside the sprite before the existing optional pixelation rasterizer so pixelated pets retain a coherent reaction appearance.

## Timing and Concurrency

Completion expiry uses a cancellable `Task` on the main actor. The task sleeps for four seconds, then clears completion only if completion is still the current reaction. Cancellation is expected when another completion restarts the timer, an error begins, or the store is deinitialized.

Session refresh remains the event source, so the reaction begins on the first refresh that observes `.idle`. No additional polling loop is introduced.

## Error Handling

- Failed scans do not replace the previous session snapshot, so recovery cannot fabricate completion transitions from missing data.
- An error cancels completion rather than pausing it.
- Cancellation of the expiry task is silent and does not become `lastError`.
- Missing optional reaction artwork uses the existing deterministic idle fallback.
- Missing idle artwork continues to use the existing visible missing-art placeholder.

## Testing

Focused `PetsCore` tests will verify:

- Initial idle sessions establish a baseline without completion.
- Newly added idle sessions do not count as observed transitions.
- Busy, waiting, and unknown sessions transitioning to idle trigger completion.
- Idle-to-idle and idle-to-busy changes do not trigger completion.
- Session identity is based on harness-qualified `HarnessSession.id`.
- Multiple completions in one snapshot produce a single completion event.
- Error and completion resolver priority is correct.
- Disabling steady status moods does not suppress reactions.
- Missing completion and error animations fall back to idle.

Store/source regression tests will verify that:

- The overlay forwards the published reaction into `PetVisualContext`.
- Error assignment is centralized through the reaction-aware helper.
- Completion expiry is cancellable and restartable.
- Static preview surfaces pass no reaction.

Verification will run focused reaction, resolver, animation, and overlay tests first, followed by `./scripts/check.sh`. The packaged app will then be rebuilt and relaunched with `./scripts/run_app.sh --verify` so visual verification uses the current bundle.

## Acceptance Criteria

- A session changing to the green-check `.idle` state makes all visible cloud pets take on the sunset treatment once for four seconds.
- Existing idle sessions at app launch do not trigger sunset.
- A second completion within four seconds restarts the four-second duration.
- Any non-`nil` `lastError` makes all visible cloud pets dark and cancels sunset.
- Clearing `lastError` immediately restores the correct normal visual state.
- Hover and steady status moods continue working when no reaction is active.
- All automated checks and the packaged-app launch verification pass.
