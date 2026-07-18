import Foundation

public struct PetsVersion: Equatable, Comparable, Sendable {
    private let components: [Int]

    public init?(_ value: String) {
        var version = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.first == "v" || version.first == "V" {
            version.removeFirst()
        }

        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty }),
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) })
        else { return nil }

        var parsed: [Int] = []
        parsed.reserveCapacity(parts.count)
        for part in parts {
            guard let component = Int(part) else { return nil }
            parsed.append(component)
        }
        while parsed.count > 1, parsed.last == 0 {
            parsed.removeLast()
        }
        components = parsed
    }

    public static func < (lhs: PetsVersion, rhs: PetsVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

public struct PetsRelease: Equatable, Sendable {
    public let version: PetsVersion
    public let displayVersion: String
    public let htmlURL: URL
    public let title: String?
    public let releaseNotes: String?

    public init(
        version: PetsVersion,
        displayVersion: String,
        htmlURL: URL,
        title: String?,
        releaseNotes: String?
    ) {
        self.version = version
        self.displayVersion = displayVersion
        self.htmlURL = htmlURL
        self.title = title
        self.releaseNotes = releaseNotes
    }
}

public enum PetsReleaseError: Error, Equatable, LocalizedError, Sendable {
    case invalidInstalledVersion(String)
    case invalidReleaseVersion(String)
    case invalidReleaseURL

    public var errorDescription: String? {
        switch self {
        case let .invalidInstalledVersion(version):
            "The installed Pets version is invalid: \(version)."
        case let .invalidReleaseVersion(version):
            "The latest GitHub release version is invalid: \(version)."
        case .invalidReleaseURL:
            "The latest GitHub release does not have a valid download page."
        }
    }
}

public enum PetsReleaseParser {
    public static func newerRelease(
        from data: Data,
        than installedVersion: String
    ) throws -> PetsRelease? {
        guard let currentVersion = PetsVersion(installedVersion) else {
            throw PetsReleaseError.invalidInstalledVersion(installedVersion)
        }

        let response = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        let displayVersion = response.tagName.first == "v" || response.tagName.first == "V"
            ? String(response.tagName.dropFirst())
            : response.tagName
        guard let releaseVersion = PetsVersion(displayVersion) else {
            throw PetsReleaseError.invalidReleaseVersion(response.tagName)
        }
        guard let url = URL(string: response.htmlURL),
              url.scheme == "https",
              url.host != nil
        else {
            throw PetsReleaseError.invalidReleaseURL
        }
        guard releaseVersion > currentVersion else { return nil }

        return PetsRelease(
            version: releaseVersion,
            displayVersion: displayVersion,
            htmlURL: url,
            title: response.name?.nilIfEmpty,
            releaseNotes: response.body?.nilIfEmpty
        )
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let htmlURL: String
    let name: String?
    let body: String?

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
