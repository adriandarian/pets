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
    @Published private(set) var isInstalling = false

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
        guard let release = availableRelease else { return }
        guard release.downloadURL != nil else { NSWorkspace.shared.open(release.htmlURL); return }
        install(release)
    }

    private func install(_ release: PetsRelease) {
        guard !isInstalling else { return }
        isInstalling = true
        Task { [weak self] in
            do { try await self?.downloadAndScheduleReplacement(release) }
            catch is CancellationError { return }
            catch {
                await MainActor.run {
                    self?.isInstalling = false
                    self?.presentFailureAlert("The update could not be installed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func downloadAndScheduleReplacement(_ release: PetsRelease) async throws {
        guard let downloadURL = release.downloadURL else { throw PetUpdateCheckError.invalidResponse }
        let (temporaryURL, response) = try await session.download(from: downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PetUpdateCheckError.invalidResponse }
        let fileManager = FileManager.default
        let stagingRoot = fileManager.temporaryDirectory.appending(path: "Pets-update-\(UUID().uuidString)")
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let archiveURL = stagingRoot.appendingPathComponent("update.zip")
        try fileManager.moveItem(at: temporaryURL, to: archiveURL)
        let extractedURL = stagingRoot.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractedURL.path])
        let newAppURL = extractedURL.appendingPathComponent("Pets.app")
        guard fileManager.fileExists(atPath: newAppURL.appendingPathComponent("Contents/MacOS/Pets").path) else { throw PetUpdateCheckError.invalidResponse }
        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        let replacementScript = stagingRoot.appendingPathComponent("replace-and-relaunch.sh")
        let script = """
        #!/bin/bash
        set -euo pipefail
        sleep 1
        while pgrep -x Pets >/dev/null 2>&1; do sleep 0.25; done
        rm -rf \(shellQuote(currentAppURL.path)).old
        mv \(shellQuote(currentAppURL.path)) \(shellQuote(currentAppURL.path)).old
        mv \(shellQuote(newAppURL.path)) \(shellQuote(currentAppURL.path))
        open -n \(shellQuote(currentAppURL.path))
        rm -rf \(shellQuote(stagingRoot.path))
        """
        try script.write(to: replacementScript, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: replacementScript.path)
        try runProcess("/usr/bin/nohup", arguments: [replacementScript.path], detached: true)
        await MainActor.run { NSApp.terminate(nil) }
    }

    private func runProcess(_ executable: String, arguments: [String], detached: Bool = false) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        if detached { process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice }
        try process.run(); if !detached { process.waitUntilExit() }
        guard detached || process.terminationStatus == 0 else { throw PetUpdateCheckError.invalidResponse }
    }

    private func shellQuote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

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
        alert.informativeText = "Pets will download and install the update, then relaunch. Your pets and preferences will stay in place."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            install(release)
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
