import AppKit
import Foundation
import PetsCore

private enum PetUpdateCheckError: Error, LocalizedError {
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "GitHub returned an invalid update response."
        case let .requestFailed(statusCode):
            "GitHub could not check for updates (HTTP \(statusCode))."
        }
    }
}

@MainActor
final class PetUpdateController: ObservableObject {
    @Published private(set) var availableRelease: PetsRelease?
    @Published private(set) var isChecking = false
    @Published private(set) var lastError: String?

    private static let releaseEndpoint = URL(
        string: "https://api.github.com/repos/adriandarian/pets/releases/latest"
    )!
    private static let automaticCheckInterval: Duration = .seconds(6 * 60 * 60)

    let installedVersion: String
    private let session: URLSession
    private let endpoint: URL
    private var checkTask: Task<Void, Never>?
    private var automaticCheckTask: Task<Void, Never>?

    init(
        installedVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0",
        session: URLSession = .shared,
        endpoint: URL = PetUpdateController.releaseEndpoint
    ) {
        self.installedVersion = installedVersion
        self.session = session
        self.endpoint = endpoint
    }

    func start() {
        checkForUpdates()
        guard automaticCheckTask == nil else { return }

        automaticCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.automaticCheckInterval)
                } catch {
                    return
                }
                guard let self else { return }
                self.checkForUpdates()
            }
        }
    }

    func checkForUpdates(showingResult: Bool = false) {
        guard checkTask == nil else { return }
        isChecking = true
        checkTask = Task { [weak self] in
            await self?.performCheck(showingResult: showingResult)
        }
    }

    func openAvailableRelease() {
        guard let url = availableRelease?.htmlURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func performCheck(showingResult: Bool) async {
        defer {
            isChecking = false
            checkTask = nil
        }

        do {
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Pets/\(installedVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw PetUpdateCheckError.invalidResponse
            }

            if response.statusCode == 404 {
                availableRelease = nil
                lastError = nil
                if showingResult {
                    presentUpToDateAlert()
                }
                return
            }
            guard response.statusCode == 200 else {
                throw PetUpdateCheckError.requestFailed(response.statusCode)
            }

            let release = try PetsReleaseParser.newerRelease(
                from: data,
                than: installedVersion
            )
            availableRelease = release
            lastError = nil

            if showingResult {
                if let release {
                    presentAvailableReleaseAlert(release)
                } else {
                    presentUpToDateAlert()
                }
            }
        } catch is CancellationError {
            return
        } catch {
            lastError = error.localizedDescription
            if showingResult {
                presentFailureAlert(error.localizedDescription)
            }
        }
    }

    private func presentAvailableReleaseAlert(_ release: PetsRelease) {
        let alert = NSAlert()
        alert.messageText = "Pets \(release.displayVersion) is available"
        alert.informativeText = "Download the latest version from GitHub and replace your existing Pets app. Your pets and preferences will stay in place."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "View on GitHub")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }

    private func presentUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "Pets is up to date"
        alert.informativeText = "You are running Pets \(installedVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentFailureAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t check for updates"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
