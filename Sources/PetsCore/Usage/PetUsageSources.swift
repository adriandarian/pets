import Foundation

public protocol PetUsageSource: Sendable {
    var id: String { get }
    var displayName: String { get }
    func read() throws -> PetUsageReading
}

public enum PetUsageSourceError: Error, Equatable, LocalizedError, Sendable {
    case executableNotFound(provider: String)
    case commandFailed(provider: String, message: String)
    case invalidOutput(provider: String)

    public var errorDescription: String? {
        switch self {
        case let .executableNotFound(provider):
            "\(provider) usage is unavailable because its local CLI was not found."
        case let .commandFailed(provider, message):
            message.isEmpty ? "\(provider) usage could not be read." : "\(provider): \(message)"
        case let .invalidOutput(provider):
            "\(provider) returned usage data Pets could not understand."
        }
    }
}
