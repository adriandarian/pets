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
              repeat with t in tabs of w
                try
                  set tabTTY to tty of t
                  if tabTTY is targetTTY or tabTTY ends with targetTTY then
                    set selected tab of w to t
                    set index of w to 1
                    activate
                    return "focused"
                  end if
                end try
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

public protocol AccessibilityPermissionChecking: Sendable {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
}

public struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    public init() {}

    public func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            let options = [
                "AXTrustedCheckOptionPrompt": true
            ] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }
}

public struct AccessibilityHostFocuser: HostAppFocusing {
    private let permissionChecker: any AccessibilityPermissionChecking

    public init(permissionChecker: any AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker()) {
        self.permissionChecker = permissionChecker
    }

    public func focus(session: ClaudeSession, host: ClaudeHostApp) throws -> ClaudeSessionActivationResult? {
        guard permissionChecker.isProcessTrusted(promptIfNeeded: true) else {
            return .permissionDenied(
                reason: "Enable Accessibility permission for ClaudePet to inspect \(host.appName) windows."
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
