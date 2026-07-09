# Pets Session Activation Design

## Goal

Clicking a Claude session bubble should move the user to the live session that bubble represents.

The feature must support sessions hosted in:

- Terminal.app (`com.apple.Terminal`)
- Ghostty (`com.mitchellh.ghostty`)
- Visual Studio Code (`com.microsoft.VSCode`)
- Visual Studio Code Insiders (`com.microsoft.VSCodeInsiders`)
- cmux (`com.cmuxterm.app`)

When Pets can identify the host app but cannot identify the exact tab or window, it must still activate the host app. It should not silently do nothing.

## Current Context

Pets is a Swift Package with:

- `PetsCore`, which scans `~/.claude/sessions/*.json`, filters dead PIDs, summarizes transcript metadata, and exposes `ClaudeSession` values.
- `Pets`, a thin AppKit and SwiftUI overlay executable.
- Existing session rows in `PetOverlayView` that have visible row content, hover dismiss controls, and reply controls, but no row activation action.

`ClaudeSession` already contains useful activation signals:

- `pid`
- `sessionId`
- `cwd`
- `title`
- `kind`
- `entrypoint`
- `replyTarget`, including terminal TTY when available

The existing reply path uses TTY targeting for terminal sessions. Activation is a separate problem because it needs to move macOS focus to the correct app and, when possible, the correct window or tab.

## Recommended Approach

Add app-specific activators behind one common interface.

A new `ClaudeSessionActivator` in `PetsCore` will expose a single activation entry point:

```swift
public func activate(_ session: ClaudeSession) throws -> ClaudeSessionActivationResult
```

The activator will:

1. Resolve the owning host app from the Claude session PID by walking the process tree.
2. Route to a host-specific activation strategy based on bundle identifier.
3. Attempt exact tab or window focus using available signals: PID, TTY, cwd, title, and accessible UI metadata.
4. If exact focus fails, activate the owning host app.
5. Return a structured result so the UI can surface permission failures or app-only fallback when useful.

This approach is preferred because macOS app activation is common, but tab selection is app-specific. A single generic tab API does not exist across Terminal, Ghostty, Electron-based editors, and cmux.

## Alternatives Considered

### Generic Accessibility Search

Pets could inspect all visible windows and tabs through Accessibility APIs and focus the best title match.

This keeps the implementation smaller, but it is less reliable. It depends heavily on UI titles, which may not contain enough session-specific information.

### URL or CLI Reopen

For VS Code-style apps, Pets could use URL schemes or CLI commands to open the workspace directory. For terminals, it could activate the app.

This is reliable for opening the right app or workspace, but it usually does not select the existing tab that owns the Claude session. It should only be used as a fallback or later enhancement.

## Architecture

### Core Types

Add these types to `PetsCore`:

```swift
public enum ClaudeSessionActivationResult: Equatable, Sendable {
    case focusedExactTarget(appName: String)
    case activatedApp(appName: String)
    case unsupportedHost(processName: String?)
    case permissionDenied(reason: String)
}

public protocol SessionActivating: Sendable {
    func activate(_ session: ClaudeSession) throws -> ClaudeSessionActivationResult
}
```

`PetStore` will depend on `SessionActivating`, similar to how it already depends on `ClaudeSessionScanner` and `ClaudeReplySender`.

### Host App Resolution

Add a process inspection component that can:

- Check whether a process is alive.
- Read process parent IDs.
- Read executable paths and process names.
- Resolve a PID to an app bundle identifier by walking ancestors.

The resolver should consider the Claude PID and its ancestors until it finds one of the supported host bundle identifiers.

Expected bundle identifiers:

- `com.apple.Terminal`
- `com.mitchellh.ghostty`
- `com.microsoft.VSCode`
- `com.microsoft.VSCodeInsiders`
- `com.cmuxterm.app`

For VS Code and VS Code Insiders, Claude sessions may be descendants of helper/plugin processes rather than direct children of the top-level app process. The resolver must walk ancestors rather than only checking the immediate parent.

### App Activation

Use `NSRunningApplication` where possible to activate the resolved host app.

Exact tab or window focusing may require Automation or Accessibility permissions. The activator should detect permission failure and return `permissionDenied` when the exact targeting layer is blocked. If the host app is known, it should still activate the app unless macOS prevents activation entirely.

### Host-Specific Strategies

#### Terminal.app

Use terminal TTY when available from `ClaudeReplyTarget.terminal(tty:)`.

The Terminal-specific strategy should try to match the session's TTY to a Terminal tab through AppleScript or Accessibility metadata. If it finds a matching tab, it should select that tab and bring Terminal forward. If not, it should activate Terminal.

#### Ghostty

Use process tree, cwd, title, and TTY signals.

Ghostty support should first activate Ghostty, then attempt exact window/tab matching through Accessibility metadata. If Ghostty does not expose a stable tab model, the first version should fall back to activating Ghostty rather than guessing.

#### VS Code and VS Code Insiders

Use process tree and cwd as primary matching signals.

For exact focus, prefer matching an existing window whose title or accessible metadata contains the session cwd, workspace folder, or session title. VS Code helper processes expose window configuration arguments at runtime, but the implementation should not depend on undocumented flags as the only source of truth.

If exact window selection fails, activate the correct VS Code variant by bundle identifier.

#### cmux

Support cmux by bundle identifier and process tree first.

Because the current machine has `cmux.app` installed but it was not observed running during design exploration, the first implementation should make cmux host detection and app fallback testable, then verify exact tab behavior manually when cmux is running.

## UI Behavior

Each visible `SessionRow` will become clickable.

Clicking the row body:

- Calls `store.activateSession(session)`.
- Should not dismiss the session.
- Should not send a reply.
- Should not trigger when clicking the dismiss button.
- Should not trigger when clicking the reply text field or Send button.

The cursor/hover treatment may remain subtle. A visible status text is not required for successful activation. Errors or permission failures can reuse `store.lastError`, which already appears in the bubble UI.

## Error Handling

Activation should never fail silently.

Expected behavior:

- Exact target found: focus the tab/window and bring app forward.
- Exact target not found: bring the resolved host app forward.
- Supported host app cannot be resolved: expose a user-visible error.
- Accessibility or Automation permission blocks exact targeting: bring the app forward when possible and expose a permission-related error.

## Testing

Unit tests should cover:

- Process-tree host detection for direct and indirect parent chains.
- Supported bundle routing for Terminal, Ghostty, VS Code, VS Code Insiders, and cmux.
- Fallback result when exact tab/window focus fails.
- Permission-denied result when exact targeting is blocked.
- `PetStore.activateSession(_:)` updates `lastError` only for actionable failures.

SwiftUI click behavior does not need deep view testing in the first pass. The row should be wired through callbacks and manually verified.

Manual verification should cover:

- Terminal.app session with multiple tabs.
- Ghostty session with multiple tabs or windows.
- VS Code session with multiple windows.
- VS Code Insiders session when installed/running.
- cmux session when running.
- Missing Accessibility or Automation permission.

## Out of Scope

- Supporting iTerm2 in the first version.
- Supporting unknown terminal emulators or editors.
- Creating new terminal/editor tabs for stale sessions.
- Reconstructing a session if the Claude process is dead.
- Persisting per-app user preferences for activation strategy.
