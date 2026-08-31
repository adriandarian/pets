import Foundation
import Testing
@testable import PetsCore

@Suite
struct LocalProviderHarnessTests {
    @Test
    func defaultDescriptorsCoverEveryAdditionalTrackingProvider() {
        let detailedProviders: Set<PetTrackingProvider> = [
            .claudeCode,
            .codex,
            .githubCopilot,
        ]
        let expected = Set(PetTrackingProvider.allCases).subtracting(detailedProviders)

        #expect(Set(LocalProviderDescriptor.defaults.map(\.provider)) == expected)
        #expect(Set(LocalProviderDescriptor.defaults.map(\.provider)).count
            == LocalProviderDescriptor.defaults.count)
    }

    @Test
    func scannerMatchesAUserFacingApplicationAndKeepsItsIdentityStable() throws {
        let launchedAt = Date(timeIntervalSince1970: 123)
        let scanner = LocalProviderSessionScanner(
            descriptor: try #require(descriptor(for: .cursor)),
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [
                        LocalApplicationSnapshot(
                            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
                            localizedName: "Cursor",
                            processID: 42,
                            isActive: false,
                            launchedAt: launchedAt
                        ),
                    ],
                    commands: []
                )
            }
        )

        let session = try #require(scanner.scan().first)

        #expect(session.harnessID == PetTrackingProvider.cursor.rawValue)
        #expect(session.sessionID == "app:42")
        #expect(session.title == "Cursor is open")
        #expect(session.entrypoint == "Cursor app")
        #expect(session.status == .idle)
        #expect(session.startedAt == launchedAt)
    }

    @Test
    func scannerTracksCLIProcessesWithoutExposingTheirArguments() throws {
        let scanner = LocalProviderSessionScanner(
            descriptor: try #require(descriptor(for: .gemini)),
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [],
                    commands: [
                        LocalCommandSnapshot(
                            processID: 73,
                            commandLine: "/usr/bin/node /Users/example/bin/gemini.js secret prompt"
                        ),
                    ]
                )
            }
        )

        let session = try #require(scanner.scan().first)

        #expect(session.sessionID == "cli:73")
        #expect(session.title == "Gemini CLI is running")
        #expect(session.chatPreview == "Local command-line activity")
        #expect(!session.title.contains("secret"))
        #expect(session.status == .busy)
    }

    @Test
    func ollamaBackgroundServerIsNotReportedAsAChat() throws {
        let scanner = LocalProviderSessionScanner(
            descriptor: try #require(descriptor(for: .ollama)),
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [],
                    commands: [
                        LocalCommandSnapshot(
                            processID: 11,
                            commandLine: "/usr/local/bin/ollama serve"
                        ),
                        LocalCommandSnapshot(
                            processID: 12,
                            commandLine: "/usr/local/bin/ollama run qwen3"
                        ),
                    ]
                )
            }
        )

        #expect(scanner.scan().map(\.processID) == [12])
    }

    @Test
    func inactiveResidentOllamaAppIsIgnoredUntilItIsInUse() throws {
        let ollamaDescriptor = try #require(descriptor(for: PetTrackingProvider.ollama))
        let inactive = LocalProviderSessionScanner(
            descriptor: ollamaDescriptor,
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [
                        LocalApplicationSnapshot(
                            bundleIdentifier: "com.electron.ollama",
                            localizedName: "Ollama",
                            processID: 90,
                            isActive: false,
                            launchedAt: nil
                        ),
                    ],
                    commands: []
                )
            }
        )
        let active = LocalProviderSessionScanner(
            descriptor: ollamaDescriptor,
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [
                        LocalApplicationSnapshot(
                            bundleIdentifier: "com.electron.ollama",
                            localizedName: "Ollama",
                            processID: 90,
                            isActive: true,
                            launchedAt: nil
                        ),
                    ],
                    commands: []
                )
            }
        )

        #expect(inactive.scan().isEmpty)
        #expect(active.scan().count == 1)
    }

    @Test
    func installedNotebookLMWebAppCanBeDetectedFromItsChromeAppProcess() throws {
        let scanner = LocalProviderSessionScanner(
            descriptor: try #require(descriptor(for: .notebookLM)),
            snapshotProvider: {
                LocalActivitySnapshot(
                    applications: [],
                    commands: [
                        LocalCommandSnapshot(
                            processID: 110,
                            commandLine: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --app-id=gjcmcplpgihbecacndmmbaenpfgimlec"
                        ),
                    ]
                )
            }
        )

        let session = try #require(scanner.scan().first)

        #expect(session.sessionID == "app-process:110")
        #expect(session.title == "NotebookLM is open")
        #expect(session.entrypoint == "NotebookLM app")
        #expect(session.status == .idle)
    }

    private func descriptor(for provider: PetTrackingProvider) -> LocalProviderDescriptor? {
        LocalProviderDescriptor.defaults.first { $0.provider == provider }
    }
}
