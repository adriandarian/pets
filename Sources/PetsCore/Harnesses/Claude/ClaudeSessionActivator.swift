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

        let appPath = NSString.path(withComponents: Array(pathComponents[0...appComponentIndex]))
        return Bundle(url: URL(filePath: appPath))?.bundleIdentifier
    }
}

public struct ClaudeHostAppResolver: Sendable {
    fileprivate let processInspector: any ActivationProcessInspecting
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
            switch result {
            case .focusedExactTarget, .permissionDenied:
                try appActivator.activate(host: host)
            case .activatedApp, .unsupportedHost:
                break
            }
            return result
        }

        try appActivator.activate(host: host)
        return .activatedApp(appName: host.appName)
    }
}
