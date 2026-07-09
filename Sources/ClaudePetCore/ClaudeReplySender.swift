import Foundation

public protocol ReplyProcessLaunching: Sendable {
    func run(executable: URL, arguments: [String], standardInput: Data) throws
}

public protocol TerminalWriting: Sendable {
    func submit(_ message: String, toTTY tty: String) throws
}

public enum ClaudeReplyError: Error, LocalizedError, Equatable {
    case emptyMessage
    case unavailable
    case unsafeTTY(String)
    case timedOut
    case processFailed(status: Int32)

    public var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Reply cannot be empty."
        case .unavailable:
            return "This session does not expose a reply target."
        case let .unsafeTTY(tty):
            return "Refusing to write to unsupported terminal \(tty)."
        case .timedOut:
            return "Reply command timed out."
        case let .processFailed(status):
            return "Reply command failed with exit status \(status)."
        }
    }
}

public struct ClaudeReplySender: Sendable {
    private let processLauncher: any ReplyProcessLaunching
    private let terminalWriter: any TerminalWriting

    public init(
        processLauncher: any ReplyProcessLaunching = ProcessReplyLauncher(),
        terminalWriter: any TerminalWriting = AppleScriptTerminalWriter()
    ) {
        self.processLauncher = processLauncher
        self.terminalWriter = terminalWriter
    }

    public func send(_ message: String, to session: ClaudeSession) throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ClaudeReplyError.emptyMessage }

        guard let replyTarget = session.replyTarget else {
            throw ClaudeReplyError.unavailable
        }

        switch replyTarget {
        case let .background(id):
            try processLauncher.run(
                executable: URL(filePath: "/usr/bin/script"),
                arguments: ["-q", "/dev/null", "claude", "attach", id],
                standardInput: Self.inputData(for: message, shouldDetach: true)
            )
        case let .terminal(tty):
            try terminalWriter.submit(message, toTTY: tty)
        }
    }

    private static func inputData(for message: String, shouldDetach: Bool) -> Data {
        var input = "\u{1B}[200~\(message)\u{1B}[201~\r"
        if shouldDetach {
            input.append("\u{1A}")
        }
        return Data(input.utf8)
    }
}

public struct ProcessReplyLauncher: ReplyProcessLaunching {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    public func run(executable: URL, arguments: [String], standardInput: Data) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        inputPipe.fileHandleForWriting.write(standardInput)
        try? inputPipe.fileHandleForWriting.close()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            throw ClaudeReplyError.timedOut
        }

        guard process.terminationStatus == 0 else {
            throw ClaudeReplyError.processFailed(status: process.terminationStatus)
        }
    }
}

public struct AppleScriptTerminalWriter: TerminalWriting {
    private let tabFocuser: any TerminalTabFocusing
    private let scriptLauncher: any ReplyProcessLaunching

    public init(
        tabFocuser: any TerminalTabFocusing = AppleScriptTerminalTabFocuser(),
        scriptLauncher: any ReplyProcessLaunching = ProcessReplyLauncher()
    ) {
        self.tabFocuser = tabFocuser
        self.scriptLauncher = scriptLauncher
    }

    public func submit(_ message: String, toTTY tty: String) throws {
        guard tty.range(of: #"^tty[a-zA-Z0-9]+$"#, options: .regularExpression) != nil else {
            throw ClaudeReplyError.unsafeTTY(tty)
        }

        guard try tabFocuser.focusTab(tty: tty) else {
            throw ClaudeReplyError.unavailable
        }

        try scriptLauncher.run(
            executable: URL(filePath: "/usr/bin/osascript"),
            arguments: ["-e", Self.submitScript, message],
            standardInput: Data()
        )
    }

    private static let submitScript = """
    on run argv
      set replyText to item 1 of argv
      set previousClipboard to the clipboard
      set the clipboard to replyText
      delay 0.05
      tell application "System Events"
        keystroke "v" using command down
        delay 0.05
        key code 36
      end tell
      delay 0.05
      set the clipboard to previousClipboard
    end run
    """
}
