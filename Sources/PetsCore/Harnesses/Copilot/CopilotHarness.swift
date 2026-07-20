import Foundation

public struct CopilotHarness: PetHarness {
    public static let defaultID = PetTrackingProvider.githubCopilot.rawValue
    public static let defaultDisplayName = "GitHub Copilot"

    public let id = CopilotHarness.defaultID
    public let displayName = CopilotHarness.defaultDisplayName

    private let scanner: CopilotSessionScanner
    private let appActivator: HarnessAppActivator

    public init(scanner: CopilotSessionScanner = CopilotSessionScanner()) {
        self.scanner = scanner
        self.appActivator = HarnessAppActivator(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "Visual Studio Code"
        )
    }

    public func scan() throws -> [HarnessSession] {
        try scanner.scan()
    }

    public func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        guard session.entrypoint == "Copilot chat" else {
            return .unsupportedHost(processName: "copilot")
        }
        return try appActivator.activate()
    }

    public func sendReply(_ message: String, to session: HarnessSession) throws {
        throw PetHarnessError.replyUnsupported(provider: displayName)
    }
}
