# Session Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clicking a Pets session bubble activates the app that owns that live Claude session and focuses the exact tab or window when it can be identified.

**Architecture:** Add a testable activation layer to `PetsCore` that resolves host apps by walking the Claude process tree, routes to host-specific focusers, and falls back to app activation. Wire `PetStore` and `SessionRow` so row clicks call the activator while reply and dismiss controls keep their current behavior.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, SwiftUI, Swift Testing, macOS Accessibility/Automation APIs, `NSRunningApplication`, `osascript` for Terminal-specific scripting.

---

## File Structure

- Create `Sources/PetsCore/ClaudeSessionActivator.swift`
  - Owns public activation result types, host app model, process-tree resolver, generic activator orchestration, and default macOS app activation.
- Create `Sources/PetsCore/HostAppFocusers.swift`
  - Owns host-specific exact focus attempts for Terminal.app, Ghostty, VS Code, VS Code Insiders, and cmux.
- Modify `Sources/Pets/PetStore.swift`
  - Injects `SessionActivating`, exposes `activateSession(_:)`, and maps activation failures to `lastError`.
- Modify `Sources/Pets/PetOverlayView.swift`
  - Adds row activation callbacks and prevents reply/dismiss controls from accidentally activating the row.
- Modify `Tests/PetsCoreTests/ClaudeSessionScannerTests.swift`
  - Adds activation core tests using local stubs. Existing test file already houses core behavior tests.
- Modify `README.md`
  - Documents click-to-activate behavior and required macOS permissions.

This workspace is not currently a git repository. Skip commit commands here; if the directory is later initialized as git, make one commit after each passing task.

## Task 1: Host App Resolution Core

**Files:**
- Create: `Sources/PetsCore/ClaudeSessionActivator.swift`
- Test: `Tests/PetsCoreTests/ClaudeSessionScannerTests.swift`

- [ ] **Step 1: Add failing tests for process-tree host resolution**

Append these tests inside `ClaudeSessionScannerTests` before `private func writeSession`:

```swift
@Test
func hostResolverFindsSupportedAncestorThroughHelperChain() {
    let resolver = ClaudeHostAppResolver(
        processInspector: StubActivationProcessInspector(
            snapshots: [
                66186: ActivationProcessSnapshot(
                    pid: 66186,
                    parentPID: 63569,
                    processName: "claude",
                    executablePath: "/Users/dariana/.vscode/extensions/anthropic.claude-code/resources/native-binary/claude",
                    bundleIdentifier: nil
                ),
                63569: ActivationProcessSnapshot(
                    pid: 63569,
                    parentPID: 63111,
                    processName: "Code Helper (Plugin)",
                    executablePath: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)",
                    bundleIdentifier: nil
                ),
                63111: ActivationProcessSnapshot(
                    pid: 63111,
                    parentPID: 1,
                    processName: "Code",
                    executablePath: "/Applications/Visual Studio Code.app/Contents/MacOS/Code",
                    bundleIdentifier: "com.microsoft.VSCode"
                )
            ]
        )
    )

    #expect(resolver.hostApp(for: 66186) == ClaudeHostApp.vsCode(pid: 63111))
}

@Test
func hostResolverSupportsRequestedBundleIdentifiers() {
    let cases: [(String, ClaudeHostApp)] = [
        ("com.apple.Terminal", .terminal(pid: 10)),
        ("com.mitchellh.ghostty", .ghostty(pid: 10)),
        ("com.microsoft.VSCode", .vscode(pid: 10)),
        ("com.microsoft.VSCodeInsiders", .vscodeInsiders(pid: 10)),
        ("com.cmuxterm.app", .cmux(pid: 10))
    ]

    for (bundleIdentifier, expectedHost) in cases {
        let resolver = ClaudeHostAppResolver(
            processInspector: StubActivationProcessInspector(
                snapshots: [
                    100: ActivationProcessSnapshot(
                        pid: 100,
                        parentPID: 10,
                        processName: "claude",
                        executablePath: "/usr/local/bin/claude",
                        bundleIdentifier: nil
                    ),
                    10: ActivationProcessSnapshot(
                        pid: 10,
                        parentPID: 1,
                        processName: "Host",
                        executablePath: "/Applications/Host.app/Contents/MacOS/Host",
                        bundleIdentifier: bundleIdentifier
                    )
                ]
            )
        )

        #expect(resolver.hostApp(for: 100) == expectedHost)
    }
}
```

Add these stubs after `RecordingTerminalWriter` or near the other test helpers:

```swift
private struct StubActivationProcessInspector: ActivationProcessInspecting {
    let snapshots: [Int32: ActivationProcessSnapshot]

    func snapshot(pid: Int32) -> ActivationProcessSnapshot? {
        snapshots[pid]
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/hostResolver'
```

Expected: fail to compile because `ClaudeHostAppResolver`, `ActivationProcessSnapshot`, `ActivationProcessInspecting`, and `ClaudeHostApp` do not exist.

- [ ] **Step 3: Implement host app resolution**

Create `Sources/PetsCore/ClaudeSessionActivator.swift`:

```swift
import AppKit
import Foundation

public enum ClaudeSessionActivationResult: Equatable, Sendable {
    case focusedExactTarget(appName: String)
    case activatedApp(appName: String)
    case unsupportedHost(processName: String?)
    case permissionDenied(reason: String)
}

public enum ClaudeHostApp: Equatable, Sendable {
    case terminal(pid: Int32)
    case ghostty(pid: Int32)
    case vscode(pid: Int32)
    case vscodeInsiders(pid: Int32)
    case cmux(pid: Int32)

    public var pid: Int32 {
        switch self {
        case let .terminal(pid),
             let .ghostty(pid),
             let .vscode(pid),
             let .vscodeInsiders(pid),
             let .cmux(pid):
            return pid
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .terminal:
            return "com.apple.Terminal"
        case .ghostty:
            return "com.mitchellh.ghostty"
        case .vscode:
            return "com.microsoft.VSCode"
        case .vscodeInsiders:
            return "com.microsoft.VSCodeInsiders"
        case .cmux:
            return "com.cmuxterm.app"
        }
    }

    public var appName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .ghostty:
            return "Ghostty"
        case .vscode:
            return "Visual Studio Code"
        case .vscodeInsiders:
            return "Visual Studio Code Insiders"
        case .cmux:
            return "cmux"
        }
    }
}

public struct ActivationProcessSnapshot: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32?
    public let processName: String
    public let executablePath: String
    public let bundleIdentifier: String?

    public init(
        pid: Int32,
        parentPID: Int32?,
        processName: String,
        executablePath: String,
        bundleIdentifier: String?
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.processName = processName
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
    }
}

public protocol ActivationProcessInspecting: Sendable {
    func snapshot(pid: Int32) -> ActivationProcessSnapshot?
}

public struct DarwinActivationProcessInspector: ActivationProcessInspecting {
    public init() {}

    public func snapshot(pid: Int32) -> ActivationProcessSnapshot? {
        guard pid > 0 else { return nil }

        let process = Process()
        process.executableURL = URL(filePath: "/bin/ps")
        process.arguments = ["-o", "pid=,ppid=,comm=", "-p", "\(pid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let output = String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return nil }

        let parts = output.split(maxSplits: 2, whereSeparator: \.isWhitespace)
        guard parts.count == 3,
              let parsedPID = Int32(parts[0]),
              let parsedParentPID = Int32(parts[1])
        else {
            return nil
        }

        let executablePath = String(parts[2])
        let processName = URL(filePath: executablePath).lastPathComponent
        return ActivationProcessSnapshot(
            pid: parsedPID,
            parentPID: parsedParentPID == 0 ? nil : parsedParentPID,
            processName: processName,
            executablePath: executablePath,
            bundleIdentifier: bundleIdentifier(forExecutablePath: executablePath)
        )
    }

    private func bundleIdentifier(forExecutablePath path: String) -> String? {
        let executableURL = URL(filePath: path)
        let pathComponents = executableURL.pathComponents
        guard let appComponentIndex = pathComponents.lastIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }

        let appPath = pathComponents[0...appComponentIndex].joined(separator: "/")
        return Bundle(url: URL(filePath: appPath))?.bundleIdentifier
    }
}

public struct ClaudeHostAppResolver: Sendable {
    private let processInspector: any ActivationProcessInspecting
    private let maxAncestorDepth: Int

    public init(
        processInspector: any ActivationProcessInspecting = DarwinActivationProcessInspector(),
        maxAncestorDepth: Int = 24
    ) {
        self.processInspector = processInspector
        self.maxAncestorDepth = maxAncestorDepth
    }

    public func hostApp(for pid: Int32) -> ClaudeHostApp? {
        var currentPID: Int32? = pid
        var visited: Set<Int32> = []
        var depth = 0

        while let pid = currentPID, depth < maxAncestorDepth, !visited.contains(pid) {
            visited.insert(pid)
            guard let snapshot = processInspector.snapshot(pid: pid) else { return nil }
            if let host = hostApp(for: snapshot) {
                return host
            }
            currentPID = snapshot.parentPID
            depth += 1
        }

        return nil
    }

    private func hostApp(for snapshot: ActivationProcessSnapshot) -> ClaudeHostApp? {
        switch snapshot.bundleIdentifier {
        case "com.apple.Terminal":
            return .terminal(pid: snapshot.pid)
        case "com.mitchellh.ghostty":
            return .ghostty(pid: snapshot.pid)
        case "com.microsoft.VSCode":
            return .vscode(pid: snapshot.pid)
        case "com.microsoft.VSCodeInsiders":
            return .vscodeInsiders(pid: snapshot.pid)
        case "com.cmuxterm.app":
            return .cmux(pid: snapshot.pid)
        default:
            return nil
        }
    }
}
```

- [ ] **Step 4: Run host resolver tests**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/hostResolver'
```

Expected: both host resolver tests pass.

## Task 2: Activation Orchestrator and Fallback Semantics

**Files:**
- Modify: `Sources/PetsCore/ClaudeSessionActivator.swift`
- Test: `Tests/PetsCoreTests/ClaudeSessionScannerTests.swift`

- [ ] **Step 1: Add failing tests for exact focus and app fallback**

Append these tests inside `ClaudeSessionScannerTests`:

```swift
@Test
func sessionActivatorReturnsExactFocusWhenHostFocuserSucceeds() throws {
    let session = makeSession(sessionId: "terminal-session", displayStatus: .waiting)
    let activator = ClaudeSessionActivator(
        hostResolver: StaticHostResolver(host: .terminal(pid: 10), processName: "Terminal"),
        hostFocuser: StubHostFocuser(result: .focusedExactTarget(appName: "Terminal")),
        appActivator: RecordingHostAppActivator()
    )

    let result = try activator.activate(session)

    #expect(result == .focusedExactTarget(appName: "Terminal"))
}

@Test
func sessionActivatorActivatesHostAppWhenExactFocusIsUnavailable() throws {
    let session = makeSession(sessionId: "ghostty-session", displayStatus: .waiting)
    let appActivator = RecordingHostAppActivator()
    let activator = ClaudeSessionActivator(
        hostResolver: StaticHostResolver(host: .ghostty(pid: 20), processName: "Ghostty"),
        hostFocuser: StubHostFocuser(result: nil),
        appActivator: appActivator
    )

    let result = try activator.activate(session)

    #expect(result == .activatedApp(appName: "Ghostty"))
    #expect(appActivator.activatedHosts == [.ghostty(pid: 20)])
}

@Test
func sessionActivatorReportsUnsupportedHostWhenNoHostAppCanBeResolved() throws {
    let session = makeSession(sessionId: "unknown-session", displayStatus: .waiting)
    let activator = ClaudeSessionActivator(
        hostResolver: StaticHostResolver(host: nil, processName: "claude"),
        hostFocuser: StubHostFocuser(result: nil),
        appActivator: RecordingHostAppActivator()
    )

    let result = try activator.activate(session)

    #expect(result == .unsupportedHost(processName: "claude"))
}
```

Add these helpers:

```swift
private struct StaticHostResolver: HostAppResolving {
    let host: ClaudeHostApp?
    let processName: String?

    func hostApp(for pid: Int32) -> ClaudeHostApp? {
        host
    }

    func processName(for pid: Int32) -> String? {
        processName
    }
}

private final class RecordingHostAppActivator: HostAppActivating, @unchecked Sendable {
    private(set) var activatedHosts: [ClaudeHostApp] = []

    func activate(host: ClaudeHostApp) throws {
        activatedHosts.append(host)
    }
}

private struct StubHostFocuser: HostAppFocusing {
    let result: ClaudeSessionActivationResult?

    func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        result
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/sessionActivator'
```

Expected: fail to compile because `ClaudeSessionActivator`, `HostAppResolving`, `HostAppActivating`, and `HostAppFocusing` are not complete.

- [ ] **Step 3: Implement orchestrator protocols and fallback activation**

Append this code to `Sources/PetsCore/ClaudeSessionActivator.swift`:

```swift
public protocol SessionActivating: Sendable {
    func activate(_ session: ClaudeSession) throws -> ClaudeSessionActivationResult
}

public protocol HostAppResolving: Sendable {
    func hostApp(for pid: Int32) -> ClaudeHostApp?
    func processName(for pid: Int32) -> String?
}

extension ClaudeHostAppResolver: HostAppResolving {
    public func processName(for pid: Int32) -> String? {
        processInspector.snapshot(pid: pid)?.processName
    }
}

public protocol HostAppFocusing: Sendable {
    func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult?
}

public protocol HostAppActivating: Sendable {
    func activate(host: ClaudeHostApp) throws
}

public enum ClaudeSessionActivationError: Error, LocalizedError, Equatable {
    case appActivationFailed(appName: String)

    public var errorDescription: String? {
        switch self {
        case let .appActivationFailed(appName):
            return "Could not activate \(appName)."
        }
    }
}

public struct MacHostAppActivator: HostAppActivating {
    public init() {}

    public func activate(host: ClaudeHostApp) throws {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: host.bundleIdentifier
        )
        guard let app = apps.first else {
            throw ClaudeSessionActivationError.appActivationFailed(appName: host.appName)
        }

        let activated = app.activate(options: [.activateAllWindows])
        guard activated else {
            throw ClaudeSessionActivationError.appActivationFailed(appName: host.appName)
        }
    }
}

public struct ClaudeSessionActivator: SessionActivating {
    private let hostResolver: any HostAppResolving
    private let hostFocuser: any HostAppFocusing
    private let appActivator: any HostAppActivating

    public init(
        hostResolver: any HostAppResolving = ClaudeHostAppResolver(),
        hostFocuser: any HostAppFocusing = CompositeHostAppFocuser(),
        appActivator: any HostAppActivating = MacHostAppActivator()
    ) {
        self.hostResolver = hostResolver
        self.hostFocuser = hostFocuser
        self.appActivator = appActivator
    }

    public func activate(_ session: ClaudeSession) throws -> ClaudeSessionActivationResult {
        guard let host = hostResolver.hostApp(for: session.pid) else {
            return .unsupportedHost(processName: hostResolver.processName(for: session.pid))
        }

        if let result = try hostFocuser.focus(session: session, host: host) {
            if case .permissionDenied = result {
                try appActivator.activate(host: host)
            }
            return result
        }

        try appActivator.activate(host: host)
        return .activatedApp(appName: host.appName)
    }
}
```

- [ ] **Step 4: Fix `ClaudeHostAppResolver` access for `processName(for:)`**

Change `ClaudeHostAppResolver` in `Sources/PetsCore/ClaudeSessionActivator.swift` so `processInspector` is visible to the extension:

```swift
public struct ClaudeHostAppResolver: Sendable {
    fileprivate let processInspector: any ActivationProcessInspecting
    private let maxAncestorDepth: Int
```

- [ ] **Step 5: Run activation orchestrator tests**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/sessionActivator'
```

Expected: all three activation orchestrator tests pass.

## Task 3: Host-Specific Focusers

**Files:**
- Create: `Sources/PetsCore/HostAppFocusers.swift`
- Test: `Tests/PetsCoreTests/ClaudeSessionScannerTests.swift`

- [ ] **Step 1: Add tests for host routing and Terminal TTY script construction**

Append these tests:

```swift
@Test
func compositeHostFocuserRoutesSupportedHosts() throws {
    let recorder = RecordingTerminalTabFocuser(result: true)
    let focuser = CompositeHostAppFocuser(
        terminalFocuser: TerminalHostFocuser(tabFocuser: recorder),
        accessibilityFocuser: StubAccessibilityHostFocuser(result: nil)
    )
    let session = ClaudeSession(
        pid: 808,
        sessionId: "terminal-session",
        cwd: "/Users/dariana/personal/Pets",
        title: "Terminal test",
        kind: "interactive",
        entrypoint: "cli",
        displayStatus: .waiting,
        replyTarget: .terminal(tty: "ttys028"),
        updatedAt: nil,
        startedAt: nil
    )

    let result = try focuser.focus(session: session, host: .terminal(pid: 10))

    #expect(result == .focusedExactTarget(appName: "Terminal"))
    #expect(recorder.requests == ["ttys028"])
}

@Test
func terminalHostFocuserFallsBackWhenSessionHasNoTTY() throws {
    let recorder = RecordingTerminalTabFocuser(result: true)
    let focuser = TerminalHostFocuser(tabFocuser: recorder)
    let session = makeSession(sessionId: "terminal-session", displayStatus: .waiting)

    let result = try focuser.focus(session: session, host: .terminal(pid: 10))

    #expect(result == nil)
    #expect(recorder.requests.isEmpty)
}

@Test
func accessibilityFocuserPermissionDeniedIsReturnedToActivator() throws {
    let focuser = StubAccessibilityHostFocuser(
        result: .permissionDenied(reason: "Accessibility permission is required to inspect Ghostty windows.")
    )

    let result = try focuser.focus(
        session: makeSession(sessionId: "ghostty-session", displayStatus: .waiting),
        host: .ghostty(pid: 20)
    )

    #expect(result == .permissionDenied(reason: "Accessibility permission is required to inspect Ghostty windows."))
}
```

Add helpers:

```swift
private final class RecordingTerminalTabFocuser: TerminalTabFocusing, @unchecked Sendable {
    let result: Bool
    private(set) var requests: [String] = []

    init(result: Bool) {
        self.result = result
    }

    func focusTab(tty: String) throws -> Bool {
        requests.append(tty)
        return result
    }
}

private struct StubAccessibilityHostFocuser: HostAppFocusing {
    let result: ClaudeSessionActivationResult?

    func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        result
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/compositeHostFocuser|ClaudeSessionScannerTests/terminalHostFocuser|ClaudeSessionScannerTests/accessibilityFocuser'
```

Expected: fail to compile because focusers do not exist.

- [ ] **Step 3: Implement host focusers**

Create `Sources/PetsCore/HostAppFocusers.swift`:

```swift
import ApplicationServices
import Foundation

public struct CompositeHostAppFocuser: HostAppFocusing {
    private let terminalFocuser: TerminalHostFocuser
    private let accessibilityFocuser: any HostAppFocusing

    public init(
        terminalFocuser: TerminalHostFocuser = TerminalHostFocuser(),
        accessibilityFocuser: any HostAppFocusing = AccessibilityHostFocuser()
    ) {
        self.terminalFocuser = terminalFocuser
        self.accessibilityFocuser = accessibilityFocuser
    }

    public func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        switch host {
        case .terminal:
            return try terminalFocuser.focus(session: session, host: host)
        case .ghostty, .vscode, .vscodeInsiders, .cmux:
            return try accessibilityFocuser.focus(session: session, host: host)
        }
    }
}

public protocol TerminalTabFocusing: Sendable {
    func focusTab(tty: String) throws -> Bool
}

public struct TerminalHostFocuser: HostAppFocusing {
    private let tabFocuser: any TerminalTabFocusing

    public init(tabFocuser: any TerminalTabFocusing = AppleScriptTerminalTabFocuser()) {
        self.tabFocuser = tabFocuser
    }

    public func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        guard case let .terminal(tty) = session.replyTarget else {
            return nil
        }

        return try tabFocuser.focusTab(tty: tty)
            ? .focusedExactTarget(appName: host.appName)
            : nil
    }
}

public struct AppleScriptTerminalTabFocuser: TerminalTabFocusing {
    public init() {}

    public func focusTab(tty: String) throws -> Bool {
        guard tty.range(of: #"^tty[a-zA-Z0-9]+$"#, options: .regularExpression) != nil else {
            return false
        }

        let source = """
        on run argv
          set targetTTY to item 1 of argv
          tell application "Terminal"
            repeat with w in windows
              set tabIndex to 1
              repeat with t in tabs of w
                try
                  if tty of t is targetTTY then
                    set selected tab of w to t
                    set index of w to 1
                    activate
                    return "focused"
                  end if
                end try
                set tabIndex to tabIndex + 1
              end repeat
            end repeat
          end tell
          return "not-found"
        end run
        """

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-e", source, tty]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return false
        }

        let response = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return response == "focused"
    }
}

public struct AccessibilityHostFocuser: HostAppFocusing {
    public init() {}

    public func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        guard AXIsProcessTrusted() else {
            return .permissionDenied(
                reason: "Accessibility permission is required to inspect \(host.appName) windows."
            )
        }

        return focusWindowByTitle(session: session, host: host)
    }

    private func focusWindowByTitle(session: ClaudeSession, host: ClaudeHostApp) -> ClaudeSessionActivationResult? {
        let appElement = AXUIElementCreateApplication(host.pid)
        var windowsValue: CFTypeRef?
        let windowsStatus = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )

        guard windowsStatus == .success,
              let windows = windowsValue as? [AXUIElement]
        else {
            return nil
        }

        let needles = matchNeedles(for: session)
        guard !needles.isEmpty else { return nil }

        for window in windows {
            guard let title = title(of: window), titleMatches(title, needles: needles) else {
                continue
            }

            AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return .focusedExactTarget(appName: host.appName)
        }

        return nil
    }

    private func matchNeedles(for session: ClaudeSession) -> [String] {
        [
            session.cwd,
            URL(filePath: session.cwd).lastPathComponent,
            session.title
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && $0 != "Untitled chat" && $0 != "No chat preview yet" }
    }

    private func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func titleMatches(_ title: String, needles: [String]) -> Bool {
        needles.contains { needle in
            title.localizedCaseInsensitiveContains(needle)
        }
    }
}
```

- [ ] **Step 4: Run focuser tests**

Run:

```bash
swift test --filter 'ClaudeSessionScannerTests/compositeHostFocuser|ClaudeSessionScannerTests/terminalHostFocuser|ClaudeSessionScannerTests/accessibilityFocuser'
```

Expected: focuser tests pass.

## Task 4: Store Integration

**Files:**
- Modify: `Sources/Pets/PetStore.swift`
- Test: build-level verification with `swift test`

- [ ] **Step 1: Modify store initializer and add activation method**

Edit `Sources/Pets/PetStore.swift`:

```swift
private let scanner: ClaudeSessionScanner
private let replySender: ClaudeReplySender
private let sessionActivator: any SessionActivating
```

Change the initializer to:

```swift
init(
    scanner: ClaudeSessionScanner = ClaudeSessionScanner(),
    replySender: ClaudeReplySender = ClaudeReplySender(),
    sessionActivator: any SessionActivating = ClaudeSessionActivator()
) {
    self.scanner = scanner
    self.replySender = replySender
    self.sessionActivator = sessionActivator
}
```

Add this method after `dismissSession(_:)`:

```swift
func activateSession(_ session: ClaudeSession) {
    let sessionActivator = self.sessionActivator
    Task {
        do {
            let result = try await Task.detached {
                try sessionActivator.activate(session)
            }.value
            applyActivationResult(result)
        } catch {
            lastError = error.localizedDescription
            lastUpdated = Date()
        }
    }
}
```

Add this helper near `applyRefreshResult`:

```swift
private func applyActivationResult(_ result: ClaudeSessionActivationResult) {
    switch result {
    case .focusedExactTarget, .activatedApp:
        lastError = nil
    case let .unsupportedHost(processName):
        lastError = "Could not find a supported app for \(processName ?? "this Claude session")."
    case let .permissionDenied(reason):
        lastError = reason
    }
    lastUpdated = Date()
}
```

- [ ] **Step 2: Run tests and build**

Run:

```bash
swift test
swift build
```

Expected: tests and build pass.

## Task 5: SwiftUI Row Click Wiring

**Files:**
- Modify: `Sources/Pets/PetOverlayView.swift`

- [ ] **Step 1: Thread activation callbacks through session bubble views**

In `SessionBubble`, update `SessionCardStack` call:

```swift
SessionCardStack(
    sessions: Array(store.visibleSessions.prefix(3)),
    overflowCount: overflowCount,
    onActivate: { session in
        store.activateSession(session)
    },
    onReply: { session, message in
        store.sendReply(message, to: session)
    },
    onDismiss: { session in
        store.dismissSession(session)
    }
)
```

In `SessionCardStack`, add the property:

```swift
let onActivate: (ClaudeSession) -> Void
```

Update `SessionRow` construction:

```swift
SessionRow(session: session) {
    onActivate(session)
} onReply: { message in
    onReply(session, message)
} onDismiss: {
    onDismiss(session)
}
```

In `SessionRow`, add:

```swift
let onActivate: () -> Void
```

and update the initializer use by changing the closure list to match the call above.

- [ ] **Step 2: Add row tap gesture without interfering with controls**

At the end of `SessionRow.body`, after `.contentShape(...)`, add:

```swift
.onTapGesture {
    guard !isReplying else { return }
    onActivate()
}
```

Leave the existing `Button` controls as buttons. SwiftUI button taps should be handled by the button and not by the row gesture when the gesture is attached to the row container.

- [ ] **Step 3: Run build**

Run:

```bash
swift build
```

Expected: build passes.

## Task 6: README and Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document activation behavior**

Add this section after `What It Reads`:

```markdown
## Session Activation

Click a visible session bubble to jump to that Claude session.

Pets supports app activation for:

- Terminal.app
- Ghostty
- Visual Studio Code
- Visual Studio Code Insiders
- cmux

When Pets can identify the owning app but cannot identify the exact tab or window, it still brings that app forward. Exact tab/window focusing may require macOS Accessibility or Automation permission.
```

- [ ] **Step 2: Run project check script**

Run:

```bash
./scripts/check.sh
```

Expected: `swift test` and `swift build` both pass.

- [ ] **Step 3: Manual verification**

Run:

```bash
./scripts/run_app.sh
```

Verify:

- Clicking a Terminal-hosted Claude session selects the matching Terminal tab when the TTY is available.
- Clicking a Ghostty-hosted Claude session brings Ghostty forward; exact window focus works when the window title includes the cwd folder or session title.
- Clicking a VS Code-hosted Claude session brings VS Code forward; exact window focus works when the window title includes the cwd folder or session title.
- Clicking a VS Code Insiders-hosted Claude session brings VS Code Insiders forward.
- Clicking a cmux-hosted Claude session brings cmux forward.
- Reply and dismiss controls still work without activating the row.

## Self-Review Notes

- Spec coverage: tasks cover host resolution, supported bundle IDs, exact focus attempts, app fallback, permission handling, row click wiring, README documentation, and verification.
- Placeholder scan: no placeholder markers or undefined future tasks are present.
- Type consistency: `ClaudeSessionActivationResult`, `SessionActivating`, `ClaudeHostApp`, `HostAppResolving`, `HostAppFocusing`, and `HostAppActivating` are introduced before use by dependent tasks.
