import Foundation

public enum BuildCLIUsageParser {
    private struct Response: Decodable {
        struct Current: Decodable {
            let startDate: String
            let tokens: Int64

            private enum CodingKeys: String, CodingKey {
                case startDate = "start_date"
                case tokens
            }
        }

        let current: Current
    }

    public static func parse(_ data: Data) throws -> PetUsageReading {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              !response.current.startDate.isEmpty
        else {
            throw PetUsageSourceError.invalidOutput(provider: "Claude")
        }
        return PetUsageReading(
            providerID: "claude",
            periodID: response.current.startDate,
            tokens: response.current.tokens
        )
    }
}

public struct BuildCLIUsageSource: PetUsageSource {
    public let id = "claude"
    public let displayName = "Claude"
    private let executableURL: URL?
    private let environment: [String: String]

    public init(
        executableURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.executableURL = executableURL
        self.environment = environment
    }

    public func read() throws -> PetUsageReading {
        guard let executable = resolvedExecutableURL() else {
            throw PetUsageSourceError.executableNotFound(provider: displayName)
        }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = [
            "usage",
            "--period", "weekly",
            "--format", "json",
            "--no-cache",
            "--no-update-check",
        ]
        process.standardOutput = output
        process.standardError = errors
        process.environment = environment.merging(["NO_COLOR": "1"]) { _, new in new }

        do {
            try process.run()
        } catch {
            throw PetUsageSourceError.commandFailed(
                provider: displayName,
                message: error.localizedDescription
            )
        }
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw PetUsageSourceError.commandFailed(provider: displayName, message: message)
        }
        return try BuildCLIUsageParser.parse(outputData)
    }

    private func resolvedExecutableURL() -> URL? {
        if let executableURL,
           FileManager.default.isExecutableFile(atPath: executableURL.path) {
            return executableURL
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates = [
            home.appendingPathComponent(".local/bin/build-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/build-cli"),
            URL(fileURLWithPath: "/usr/local/bin/build-cli"),
        ]
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent("build-cli")
            })
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
