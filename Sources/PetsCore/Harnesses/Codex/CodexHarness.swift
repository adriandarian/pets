import Foundation

public struct CodexHarness: PetHarness {
    public static let defaultID = PetTrackingProvider.codex.rawValue
    public static let defaultDisplayName = "Codex"

    public let id = CodexHarness.defaultID
    public let displayName = CodexHarness.defaultDisplayName

    private let scanner: CodexSessionScanner
    private let appActivator: HarnessAppActivator

    public init(scanner: CodexSessionScanner = CodexSessionScanner()) {
        self.scanner = scanner
        self.appActivator = HarnessAppActivator(
            bundleIdentifier: "com.openai.codex",
            displayName: Self.defaultDisplayName
        )
    }

    public func scan() throws -> [HarnessSession] {
        try scanner.scan()
    }

    public func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        try appActivator.activate()
    }

    public func sendReply(_ message: String, to session: HarnessSession) throws {
        throw PetHarnessError.replyUnsupported(provider: displayName)
    }
}
