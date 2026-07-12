# Pet Reaction Moods Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every visible cloud pet celebrate a newly green-checked session with a four-second sunset treatment and remain dark while an app error is active.

**Architecture:** A pure `PetsCore` detector compares harness-qualified session snapshots and reports newly observed transitions into `.idle`. `PetStore` coordinates the transient completion timer and persistent error reaction, while `PetVisualContext` and the asset renderer resolve and display reactions above existing hover and steady status moods.

**Tech Stack:** Swift 6, SwiftUI, Swift Concurrency, Swift Testing, Swift Package Manager, macOS 14+

## Global Constraints

- Completion is triggered by an existing observed `HarnessSession` changing from a non-idle status to `.idle`.
- The first successful scan and newly appearing idle sessions must not trigger completion.
- Completion lasts four seconds; another completion restarts the four-second interval.
- Error remains active while `PetStore.lastError` is non-`nil`, has priority over completion, and cancels completion.
- Clearing an error returns directly to normal state without restoring an earlier completion.
- Reactions are harness-neutral, shared by all visible pets, and are not persisted.
- No new settings, sounds, notifications, particles, rain, lightning, or generated reaction assets.
- Runtime treatments must preserve PNG transparency and run before optional pixelation.
- Existing steady `Status moods` settings do not suppress completion or error reactions.

---

## File Map

- Create `Sources/PetsCore/Pets/PetSessionTransitionDetector.swift`: pure snapshot comparison for newly idle sessions.
- Create `Sources/PetsCore/Pets/PetReaction.swift`: public reaction vocabulary shared by store, resolver, and renderer.
- Create `Tests/PetsCoreTests/Pets/PetSessionTransitionDetectorTests.swift`: transition semantics and harness-qualified identity.
- Modify `Sources/PetsCore/Pets/PetAnimation.swift`: add reaction visual states and optional reaction animations.
- Modify `Sources/PetsCore/Pets/PetVisualStateResolver.swift`: carry reaction context and enforce reaction priority.
- Modify `Sources/Pets/PetStore.swift`: publish reactions, centralize error mutation, and coordinate completion expiry.
- Modify `Sources/Pets/PetOverlayView.swift`: forward the store reaction to live pet sprites.
- Modify `Sources/Pets/PetSprites.swift`: apply sunset and dark-cloud runtime treatments.
- Modify `Tests/PetsCoreTests/Pets/PetAnimationTests.swift`: cover reaction animation fallback.
- Modify `Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift`: cover reaction priority and settings independence.
- Modify `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`: include future reaction assets in resource validation.
- Modify `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`: guard store coordination and live overlay wiring.
- Modify `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`: guard transparent reaction rendering and timeline behavior.

---

### Task 1: Detect Newly Green-Checked Sessions

**Files:**
- Create: `Tests/PetsCoreTests/Pets/PetSessionTransitionDetectorTests.swift`
- Create: `Sources/PetsCore/Pets/PetSessionTransitionDetector.swift`

**Interfaces:**
- Consumes: `[HarnessSession]` and each session's harness-qualified `id` plus `HarnessSessionStatus`.
- Produces: `public mutating func observe(_ sessions: [HarnessSession]) -> Bool` on `PetSessionTransitionDetector`.

- [ ] **Step 1: Write the failing detector tests**

Create `Tests/PetsCoreTests/Pets/PetSessionTransitionDetectorTests.swift`:

```swift
import Testing
@testable import PetsCore

@Suite
struct PetSessionTransitionDetectorTests {
    @Test
    func initialSnapshotAndNewIdleSessionsDoNotComplete() {
        var detector = PetSessionTransitionDetector()

        #expect(!detector.observe([session(id: "existing", status: .idle)]))
        #expect(!detector.observe([
            session(id: "existing", status: .idle),
            session(id: "new", status: .idle),
        ]))
    }

    @Test
    func everyObservedNonIdleToIdleTransitionCompletes() {
        for status in [HarnessSessionStatus.busy, .waiting, .unknown] {
            var detector = PetSessionTransitionDetector()
            #expect(!detector.observe([session(id: "chat", status: status)]))
            #expect(detector.observe([session(id: "chat", status: .idle)]))
        }
    }

    @Test
    func unchangedIdleAndIdleToBusyDoNotComplete() {
        var unchangedDetector = PetSessionTransitionDetector()
        #expect(!unchangedDetector.observe([session(id: "chat", status: .idle)]))
        #expect(!unchangedDetector.observe([session(id: "chat", status: .idle)]))

        var busyDetector = PetSessionTransitionDetector()
        #expect(!busyDetector.observe([session(id: "chat", status: .idle)]))
        #expect(!busyDetector.observe([session(id: "chat", status: .busy)]))
    }

    @Test
    func sessionIdentityIncludesHarnessID() {
        var detector = PetSessionTransitionDetector()

        #expect(!detector.observe([
            session(harnessID: "claude", id: "shared", status: .busy),
        ]))
        #expect(!detector.observe([
            session(harnessID: "codex", id: "shared", status: .idle),
        ]))
    }

    @Test
    func multipleTransitionsProduceOneCompletionSignal() {
        var detector = PetSessionTransitionDetector()

        #expect(!detector.observe([
            session(id: "one", status: .busy),
            session(id: "two", status: .waiting),
        ]))
        #expect(detector.observe([
            session(id: "one", status: .idle),
            session(id: "two", status: .idle),
        ]))
    }

    private func session(
        harnessID: String = "test-harness",
        id: String,
        status: HarnessSessionStatus
    ) -> HarnessSession {
        HarnessSession(
            harnessID: harnessID,
            harnessDisplayName: "Test Harness",
            sessionID: id,
            processID: 42,
            cwd: "/tmp",
            title: id,
            kind: "interactive",
            entrypoint: "cli",
            status: status,
            updatedAt: nil,
            startedAt: nil
        )
    }
}
```

- [ ] **Step 2: Run the detector tests and verify the missing-type failure**

Run:

```bash
swift test --filter PetSessionTransitionDetectorTests
```

Expected: compilation fails because `PetSessionTransitionDetector` does not exist.

- [ ] **Step 3: Implement the pure transition detector**

Create `Sources/PetsCore/Pets/PetSessionTransitionDetector.swift`:

```swift
public struct PetSessionTransitionDetector: Sendable {
    private var previousStatuses: [String: HarnessSessionStatus]?

    public init() {}

    @discardableResult
    public mutating func observe(_ sessions: [HarnessSession]) -> Bool {
        var currentStatuses: [String: HarnessSessionStatus] = [:]
        for session in sessions {
            currentStatuses[session.id] = session.status
        }

        defer { previousStatuses = currentStatuses }
        guard let previousStatuses else { return false }

        return currentStatuses.contains { id, status in
            guard status == .idle, let previousStatus = previousStatuses[id] else {
                return false
            }
            return previousStatus != .idle
        }
    }
}
```

- [ ] **Step 4: Run the focused detector tests**

Run:

```bash
swift test --filter PetSessionTransitionDetectorTests
```

Expected: all five detector tests pass.

- [ ] **Step 5: Commit the detector**

```bash
git add Sources/PetsCore/Pets/PetSessionTransitionDetector.swift Tests/PetsCoreTests/Pets/PetSessionTransitionDetectorTests.swift
git commit -m "feat: detect completed pet sessions"
```

---

### Task 2: Add Reactions to the Core Visual Model

**Files:**
- Create: `Sources/PetsCore/Pets/PetReaction.swift`
- Modify: `Sources/PetsCore/Pets/PetAnimation.swift`
- Modify: `Sources/PetsCore/Pets/PetVisualStateResolver.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetAnimationTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetArtResourceTests.swift`

**Interfaces:**
- Consumes: the existing `PetVisualContext`, `PetVisualStateResolver`, and `PetArtPack` contracts.
- Produces: `PetReaction`, `PetVisualContext.reaction`, `.completion` and `.error` visual states, plus optional `PetArtPack.completion` and `.error` animations.

- [ ] **Step 1: Write failing resolver and art-pack tests**

Add these tests to `PetVisualStateResolverTests`:

```swift
@Test
func reactionsOverrideHoverAndSteadyStatusMoods() {
    let completion = PetVisualContext(
        status: .waiting,
        hasActiveSessions: true,
        isHovered: true,
        animationSettings: .default,
        reaction: .completion
    )
    let error = PetVisualContext(
        status: .busy,
        hasActiveSessions: true,
        isHovered: true,
        animationSettings: .default,
        reaction: .error
    )

    #expect(PetVisualStateResolver.requestedState(for: completion) == .completion)
    #expect(PetVisualStateResolver.requestedState(for: error) == .error)
}

@Test
func disabledSteadyStatusMoodsDoNotSuppressReactions() {
    let settings = PetAnimationSettings(
        isHoverBounceEnabled: false,
        isIdleMotionEnabled: false,
        areStatusMoodsEnabled: false
    )
    let context = PetVisualContext(
        status: .busy,
        hasActiveSessions: true,
        isHovered: false,
        animationSettings: settings,
        reaction: .completion
    )

    #expect(PetVisualStateResolver.requestedState(for: context) == .completion)
}
```

Extend `missingOptionalStateResolvesDirectlyToIdle()` in `PetAnimationTests` with:

```swift
#expect(pack.animation(for: .completion) == nil)
#expect(pack.animation(for: .error) == nil)
#expect(pack.resolvedAnimation(for: .completion) == idle)
#expect(pack.resolvedAnimation(for: .error) == idle)
```

In `PetArtResourceTests.registeredAssetPacksUseValidProductionFrames()`, replace the animation collection with:

```swift
let animations = [
    pack.idle,
    pack.busy,
    pack.waiting,
    pack.excited,
    pack.sleeping,
    pack.completion,
    pack.error,
].compactMap { $0 }
```

- [ ] **Step 2: Run focused tests and verify the missing reaction API failure**

Run:

```bash
swift test --filter PetVisualStateResolverTests
swift test --filter PetAnimationTests
```

Expected: compilation fails because `PetReaction`, the new visual states, and reaction art-pack properties do not exist.

- [ ] **Step 3: Implement the reaction vocabulary and resolver priority**

Create `Sources/PetsCore/Pets/PetReaction.swift`:

```swift
public enum PetReaction: Equatable, Sendable {
    case completion
    case error
}
```

In `PetAnimation.swift`, extend `PetVisualState`:

```swift
public enum PetVisualState: String, CaseIterable, Sendable {
    case idle
    case busy
    case waiting
    case excited
    case sleeping
    case completion
    case error
}
```

Replace `PetArtPack` with:

```swift
public struct PetArtPack: Equatable, Sendable {
    public let idle: PetAnimation
    public let busy: PetAnimation?
    public let waiting: PetAnimation?
    public let excited: PetAnimation?
    public let sleeping: PetAnimation?
    public let completion: PetAnimation?
    public let error: PetAnimation?

    public init(
        idle: PetAnimation,
        busy: PetAnimation? = nil,
        waiting: PetAnimation? = nil,
        excited: PetAnimation? = nil,
        sleeping: PetAnimation? = nil,
        completion: PetAnimation? = nil,
        error: PetAnimation? = nil
    ) {
        self.idle = idle
        self.busy = busy
        self.waiting = waiting
        self.excited = excited
        self.sleeping = sleeping
        self.completion = completion
        self.error = error
    }

    public func animation(for state: PetVisualState) -> PetAnimation? {
        switch state {
        case .idle:
            idle
        case .busy:
            busy
        case .waiting:
            waiting
        case .excited:
            excited
        case .sleeping:
            sleeping
        case .completion:
            completion
        case .error:
            error
        }
    }

    public func resolvedAnimation(for state: PetVisualState) -> PetAnimation {
        animation(for: state) ?? idle
    }
}
```

Replace `PetVisualContext` and the first part of the resolver in `PetVisualStateResolver.swift` with:

```swift
public struct PetVisualContext: Equatable, Sendable {
    public let status: HarnessSessionStatus
    public let hasActiveSessions: Bool
    public let isHovered: Bool
    public let animationSettings: PetAnimationSettings
    public let reaction: PetReaction?

    public init(
        status: HarnessSessionStatus,
        hasActiveSessions: Bool,
        isHovered: Bool,
        animationSettings: PetAnimationSettings,
        reaction: PetReaction? = nil
    ) {
        self.status = status
        self.hasActiveSessions = hasActiveSessions
        self.isHovered = isHovered
        self.animationSettings = animationSettings
        self.reaction = reaction
    }
}

public enum PetVisualStateResolver {
    public static func requestedState(for context: PetVisualContext) -> PetVisualState {
        switch context.reaction {
        case .some(.completion):
            return .completion
        case .some(.error):
            return .error
        case nil:
            break
        }

        if context.isHovered && context.animationSettings.isHoverBounceEnabled {
            return .excited
        }
        guard context.animationSettings.areStatusMoodsEnabled else { return .idle }
        guard context.hasActiveSessions else { return .sleeping }

        switch context.status {
        case .waiting:
            return .waiting
        case .busy:
            return .busy
        case .idle, .unknown:
            return .idle
        }
    }
}
```

- [ ] **Step 4: Run all focused core visual tests**

Run:

```bash
swift test --filter PetVisualStateResolverTests
swift test --filter PetAnimationTests
swift test --filter PetArtResourceTests
```

Expected: all resolver, animation, and resource tests pass.

- [ ] **Step 5: Commit the core reaction model**

```bash
git add Sources/PetsCore/Pets/PetReaction.swift Sources/PetsCore/Pets/PetAnimation.swift Sources/PetsCore/Pets/PetVisualStateResolver.swift Tests/PetsCoreTests/Pets/PetAnimationTests.swift Tests/PetsCoreTests/Pets/PetVisualStateResolverTests.swift Tests/PetsCoreTests/Pets/PetArtResourceTests.swift
git commit -m "feat: add pet reaction visual states"
```

---

### Task 3: Coordinate Completion and Error Reactions in PetStore

**Files:**
- Modify: `Sources/Pets/PetStore.swift`
- Modify: `Sources/Pets/PetOverlayView.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift`

**Interfaces:**
- Consumes: `PetSessionTransitionDetector.observe(_:)` and `PetReaction` from Tasks 1 and 2.
- Produces: `PetStore.currentReaction`, centralized `setLastError(_:)`, restartable four-second completion expiry, and live overlay reaction forwarding.

- [ ] **Step 1: Write failing source-level coordination tests**

Add these tests to `PetOverlayTransparencyTests`:

```swift
@Test
func petStoreCoordinatesCompletionAndErrorReactions() throws {
    let sourceURL = try sourceFile("Sources/Pets/PetStore.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(source.contains("@Published private(set) var currentReaction: PetReaction?"))
    #expect(source.contains("private var sessionTransitionDetector = PetSessionTransitionDetector()"))
    #expect(source.contains("private static let completionReactionDuration: Duration = .seconds(4)"))
    #expect(source.contains("sessionTransitionDetector.observe(scannedSessions)"))
    #expect(source.contains("private func beginCompletionReaction()"))
    #expect(source.contains("private func setLastError(_ error: String?)"))
    #expect(source.contains("completionReactionTask?.cancel()"))
    #expect(source.contains("guard let self, self.currentReaction == .completion else { return }"))
    #expect(!source.contains("lastError = error.localizedDescription"))
    #expect(!source.contains("lastError = nil"))
}

@Test
func liveOverlayForwardsCurrentReactionToPetSprite() throws {
    let sourceURL = try sourceFile("Sources/Pets/PetOverlayView.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    #expect(source.contains("reaction: store.currentReaction"))
}
```

- [ ] **Step 2: Run the source tests and verify they fail on missing coordination**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: the two new tests fail because the store has no reaction state and the overlay does not forward it.

- [ ] **Step 3: Add published state, detector, timer, and initial-error handling**

Add these properties to `PetStore`:

```swift
@Published private(set) var currentReaction: PetReaction?

private var sessionTransitionDetector = PetSessionTransitionDetector()
private var completionReactionTask: Task<Void, Never>?
private static let completionReactionDuration: Duration = .seconds(4)
```

After loading settings in `init`, initialize both error properties:

```swift
self.lastError = loadedPetConfiguration.error
self.currentReaction = loadedPetConfiguration.error == nil ? nil : .error
```

Extend `deinit`:

```swift
deinit {
    refreshTask?.cancel()
    completionReactionTask?.cancel()
}
```

- [ ] **Step 4: Centralize error state and completion expiry**

Add these helpers to `PetStore`:

```swift
private func setLastError(_ error: String?) {
    if error != nil {
        completionReactionTask?.cancel()
        completionReactionTask = nil
        currentReaction = .error
    } else if currentReaction == .error {
        currentReaction = nil
    }

    if lastError != error {
        lastError = error
    }
}

private func beginCompletionReaction() {
    completionReactionTask?.cancel()
    currentReaction = .completion

    completionReactionTask = Task { @MainActor [weak self] in
        do {
            try await Task.sleep(for: Self.completionReactionDuration)
        } catch {
            return
        }

        guard let self, self.currentReaction == .completion else { return }
        self.currentReaction = nil
        self.completionReactionTask = nil
    }
}
```

Replace `applyRefreshResult` with:

```swift
private func applyRefreshResult(sessions scannedSessions: [HarnessSession]?, error: String?) {
    if let scannedSessions {
        let didCompleteSession = sessionTransitionDetector.observe(scannedSessions)
        if sessions != scannedSessions {
            sessions = scannedSessions
            dismissedSessions.formIntersection(scannedSessions.map(PetDismissedSession.init))
        }

        setLastError(error)
        if error == nil, didCompleteSession {
            beginCompletionReaction()
        }
    } else {
        setLastError(error)
    }
    lastUpdated = Date()
}
```

Route every other error mutation through `setLastError`:

```swift
func recordError(_ error: String) {
    setLastError(error)
    lastUpdated = Date()
}
```

In the activation catch, use:

```swift
setLastError(error.localizedDescription)
lastUpdated = Date()
```

In successful reply sending, use:

```swift
setLastError(nil)
await refresh()
```

In the reply catch, use:

```swift
setLastError(error.localizedDescription)
lastUpdated = Date()
```

Replace `applyActivationResult` with:

```swift
private func applyActivationResult(_ result: HarnessActivationResult) {
    switch result {
    case .focusedExactTarget, .activatedApp:
        setLastError(nil)
    case let .unsupportedHost(processName):
        setLastError("Could not find a supported app for \(processName ?? "this session").")
    case let .permissionDenied(reason):
        setLastError(reason)
    }
    lastUpdated = Date()
}
```

- [ ] **Step 5: Forward the reaction from the overlay**

In the live `PetVisualContext` inside `PetOverlayView`, add the final argument:

```swift
visualContext: PetVisualContext(
    status: store.dominantStatus,
    hasActiveSessions: !store.visibleSessions.isEmpty,
    isHovered: isPetHovered,
    animationSettings: petInstance.animationSettings,
    reaction: store.currentReaction
)
```

- [ ] **Step 6: Run the focused coordination tests**

Run:

```bash
swift test --filter PetOverlayTransparencyTests
```

Expected: all overlay and store source-regression tests pass.

- [ ] **Step 7: Commit store coordination**

```bash
git add Sources/Pets/PetStore.swift Sources/Pets/PetOverlayView.swift Tests/PetsCoreTests/Pets/PetOverlayTransparencyTests.swift
git commit -m "feat: coordinate pet completion and error reactions"
```

---

### Task 4: Render Sunset and Dark-Cloud Treatments

**Files:**
- Modify: `Sources/Pets/PetSprites.swift`
- Modify: `Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift`

**Interfaces:**
- Consumes: `PetVisualContext.reaction`, the resolved reaction animation, and the existing idle-motion setting.
- Produces: `PetReactionVisualModifier` with transparent sunset/error treatments applied before `pixelatedSpriteEffect`.

- [ ] **Step 1: Write the failing rendering source test**

Add this test to `PetSpriteSourceTests`:

```swift
@Test
func petSpriteAppliesTransparentReactionTreatmentsBeforePixelation() throws {
    let source = try source("Sources/Pets/PetSprites.swift")

    #expect(source.contains("PetReactionVisualModifier("))
    #expect(source.contains("reaction: visualContext.reaction"))
    #expect(source.contains("LinearGradient("))
    #expect(source.contains(".mask(content)"))
    #expect(source.contains(".saturation(0.28)"))
    #expect(source.contains(".brightness(-0.18)"))
    #expect(source.contains("visualContext.reaction != nil"))

    let reactionModifier = try #require(source.range(of: "private struct PetReactionVisualModifier"))
    let pixelation = try #require(source.range(of: "private extension View"))
    #expect(reactionModifier.lowerBound < pixelation.lowerBound)
}
```

- [ ] **Step 2: Run the rendering test and verify it fails**

Run:

```bash
swift test --filter PetSpriteSourceTests
```

Expected: the new test fails because `PetReactionVisualModifier` is absent.

- [ ] **Step 3: Keep the animation timeline active for reaction motion**

Replace `usesTimeline` in `AssetPetSprite` with:

```swift
private var usesTimeline: Bool {
    visualContext.animationSettings.isIdleMotionEnabled
        && (
            animation.frames.count > 1
                || animation.motion != .none
                || visualContext.reaction != nil
        )
}
```

- [ ] **Step 4: Apply the reaction treatment to the pet image**

Immediately after the existing `PetMotionModifier`, add:

```swift
.modifier(
    PetReactionVisualModifier(
        reaction: visualContext.reaction,
        elapsed: elapsed,
        isMotionEnabled: visualContext.animationSettings.isIdleMotionEnabled
    )
)
```

Add this modifier below `PetMotionModifier` and above the pixelation extension:

```swift
private struct PetReactionVisualModifier: ViewModifier {
    let reaction: PetReaction?
    let elapsed: TimeInterval
    let isMotionEnabled: Bool

    private var phase: CGFloat {
        CGFloat(sin(elapsed * 2.8))
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch reaction {
        case .some(.completion):
            content
                .saturation(1.18)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.72, blue: 0.24),
                            Color(red: 1.0, green: 0.38, blue: 0.34),
                            Color(red: 0.76, green: 0.35, blue: 0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.72)
                    .mask(content)
                }
                .shadow(
                    color: Color(red: 1.0, green: 0.48, blue: 0.22).opacity(0.48),
                    radius: 9,
                    y: 1
                )
                .scaleEffect(isMotionEnabled ? 1 + (phase + 1) * 0.012 : 1)
                .offset(y: isMotionEnabled ? -2 - phase * 1.2 : 0)
        case .some(.error):
            content
                .saturation(0.28)
                .brightness(-0.18)
                .colorMultiply(Color(red: 0.55, green: 0.62, blue: 0.72))
                .shadow(color: Color.black.opacity(0.42), radius: 7, y: 3)
                .offset(y: isMotionEnabled ? 2 + abs(phase) * 0.8 : 0)
        case nil:
            content
        }
    }
}
```

- [ ] **Step 5: Run focused renderer and core visual tests**

Run:

```bash
swift test --filter PetSpriteSourceTests
swift test --filter PetVisualStateResolverTests
swift test --filter PetAnimationTests
```

Expected: all focused renderer and visual-model tests pass.

- [ ] **Step 6: Commit the runtime treatments**

```bash
git add Sources/Pets/PetSprites.swift Tests/PetsCoreTests/Pets/PetSpriteSourceTests.swift
git commit -m "feat: animate sunset and dark cloud reactions"
```

---

### Task 5: Verify the Complete Feature and Packaged App

**Files:**
- Verify: all files changed in Tasks 1-4
- Verify bundle: `dist/Pets.app`

**Interfaces:**
- Consumes: the complete reaction detector, store coordinator, resolver, and renderer.
- Produces: fresh automated, build, bundle-launch, and manual visual evidence.

- [ ] **Step 1: Run all focused reaction gates together**

Run:

```bash
swift test --filter PetSessionTransitionDetectorTests
swift test --filter PetVisualStateResolverTests
swift test --filter PetAnimationTests
swift test --filter PetArtResourceTests
swift test --filter PetOverlayTransparencyTests
swift test --filter PetSpriteSourceTests
```

Expected: every focused suite passes with no failures.

- [ ] **Step 2: Run the repository verification gate**

Run:

```bash
./scripts/check.sh
```

Expected: the full Swift test suite passes and the debug build exits successfully.

- [ ] **Step 3: Rebuild and relaunch the packaged app**

Run:

```bash
./scripts/run_app.sh --verify
```

Expected: output contains `Launched dist/Pets.app`, and `pgrep -x Pets` finds the launched bundle process.

- [ ] **Step 4: Verify the two live visual transitions**

Use a real visible session and confirm:

1. While the session is busy, its spinner and the ordinary busy pet mood remain unchanged.
2. When that same session first shows the green check, every visible pet receives the warm sunset gradient and gentle lift.
3. Four seconds after the newest green check, pets return to their correct steady mood.
4. When the app displays a real session/activation/reply error, every visible pet becomes dark and desaturated.
5. When that error clears through the existing recovery path, pets immediately return to the correct steady mood without replaying sunset.
6. Pet edges remain transparent and pixelated pets do not gain rectangular reaction backgrounds.

- [ ] **Step 5: Inspect the final diff and commit any verification-only correction**

Run:

```bash
git status --short
git diff --check
git log -5 --oneline
```

Expected: no unintended files, no whitespace errors, and the three implementation commits are present after the design/plan commits. If visual verification required a correction, repeat its focused red-green test cycle and commit only that correction with a descriptive `fix:` message.
