import Foundation

public enum PetHarnessError: Error, Equatable, LocalizedError, Sendable {
    case unknownProvider(String)
    case replyUnsupported(provider: String)
    case activationFailed(provider: String)

    public var errorDescription: String? {
        switch self {
        case let .unknownProvider(provider):
            "No session tracker is registered for \(provider)."
        case let .replyUnsupported(provider):
            "Replies are not supported for \(provider) sessions yet."
        case let .activationFailed(provider):
            "Pets could not open \(provider)."
        }
    }
}

public struct MultiProviderHarness: PetHarness {
    public let id = "multi-provider"
    public let displayName = "Developer chats"

    private let harnesses: [any PetHarness]

    public init(
        harnesses: [any PetHarness] = [
            ClaudeHarness(),
            CodexHarness(),
            CopilotHarness(),
        ]
    ) {
        self.harnesses = harnesses
    }

    public func scan() throws -> [HarnessSession] {
        var sessions: [HarnessSession] = []
        var firstError: (any Error)?
        var successfulProviderCount = 0

        for harness in harnesses {
            do {
                sessions.append(contentsOf: try harness.scan())
                successfulProviderCount += 1
            } catch {
                firstError = firstError ?? error
            }
        }

        if successfulProviderCount == 0, let firstError {
            throw firstError
        }

        return sessions.sorted { lhs, rhs in
            switch (lhs.updatedAt, rhs.updatedAt) {
            case let (left?, right?):
                left > right
            case (.some, .none):
                true
            case (.none, .some):
                false
            case (.none, .none):
                lhs.startedAt ?? .distantPast > rhs.startedAt ?? .distantPast
            }
        }
    }

    public func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        guard let harness = harnesses.first(where: { $0.id == session.harnessID }) else {
            throw PetHarnessError.unknownProvider(session.harnessID)
        }
        return try harness.activate(session)
    }

    public func sendReply(_ message: String, to session: HarnessSession) throws {
        guard let harness = harnesses.first(where: { $0.id == session.harnessID }) else {
            throw PetHarnessError.unknownProvider(session.harnessID)
        }
        try harness.sendReply(message, to: session)
    }
}

struct HarnessAppActivator: Sendable {
    let bundleIdentifier: String
    let displayName: String

    func activate() throws -> HarnessActivationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleIdentifier]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PetHarnessError.activationFailed(provider: displayName)
        }
        return .activatedApp(appName: displayName)
    }
}
