import AppKit
import Foundation

struct LocalProviderDescriptor: Equatable, Sendable {
    enum ApplicationPolicy: Equatable, Sendable {
        case running
        case activeOnly
    }

    let provider: PetTrackingProvider
    let bundleIdentifiers: [String]
    let applicationNames: [String]
    let applicationCommandMarkers: [String]
    let cliExecutableNames: Set<String>
    let ignoredCLISubcommands: Set<String>
    let applicationPolicy: ApplicationPolicy

    init(
        provider: PetTrackingProvider,
        bundleIdentifiers: [String] = [],
        applicationNames: [String] = [],
        applicationCommandMarkers: [String] = [],
        cliExecutableNames: Set<String> = [],
        ignoredCLISubcommands: Set<String> = [],
        applicationPolicy: ApplicationPolicy = .running
    ) {
        self.provider = provider
        self.bundleIdentifiers = bundleIdentifiers
        self.applicationNames = applicationNames
        self.applicationCommandMarkers = applicationCommandMarkers
        self.cliExecutableNames = cliExecutableNames
        self.ignoredCLISubcommands = ignoredCLISubcommands
        self.applicationPolicy = applicationPolicy
    }

    static let defaults: [LocalProviderDescriptor] = [
        LocalProviderDescriptor(
            provider: .cursor,
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
            applicationNames: ["Cursor"],
            cliExecutableNames: ["cursor"]
        ),
        LocalProviderDescriptor(
            provider: .ollama,
            bundleIdentifiers: ["com.electron.ollama"],
            applicationNames: ["Ollama"],
            cliExecutableNames: ["ollama"],
            ignoredCLISubcommands: ["serve"],
            applicationPolicy: .activeOnly
        ),
        LocalProviderDescriptor(
            provider: .gemini,
            bundleIdentifiers: ["com.google.GeminiMacOS"],
            applicationNames: ["Gemini"],
            cliExecutableNames: ["gemini"]
        ),
        LocalProviderDescriptor(
            provider: .antigravity,
            bundleIdentifiers: ["com.google.antigravity-ide", "com.google.antigravity"],
            applicationNames: ["Antigravity IDE", "Antigravity"],
            cliExecutableNames: ["antigravity", "antigravity-cli"]
        ),
        LocalProviderDescriptor(
            provider: .hermes,
            bundleIdentifiers: ["com.nousresearch.hermes.setup"],
            applicationNames: ["Hermes"],
            cliExecutableNames: ["hermes"]
        ),
        LocalProviderDescriptor(
            provider: .t3Code,
            bundleIdentifiers: ["com.t3tools.t3code"],
            applicationNames: ["T3 Code", "T3 Code (Alpha)"]
        ),
        LocalProviderDescriptor(
            provider: .openDesign,
            bundleIdentifiers: ["io.open-design.desktop"],
            applicationNames: ["Open Design"]
        ),
        LocalProviderDescriptor(
            provider: .kiro,
            bundleIdentifiers: ["dev.kiro.desktop", "com.amazon.codewhisperer"],
            applicationNames: ["Kiro", "Kiro CLI"],
            cliExecutableNames: ["kiro", "kiro-cli"]
        ),
        LocalProviderDescriptor(
            provider: .zed,
            bundleIdentifiers: ["dev.zed.Zed"],
            applicationNames: ["Zed"],
            cliExecutableNames: ["zed"]
        ),
        LocalProviderDescriptor(
            provider: .windsurf,
            bundleIdentifiers: ["com.exafunction.windsurf"],
            applicationNames: ["Windsurf"],
            cliExecutableNames: ["windsurf"]
        ),
        LocalProviderDescriptor(
            provider: .openCode,
            applicationNames: ["opencode"],
            cliExecutableNames: ["opencode"]
        ),
        LocalProviderDescriptor(
            provider: .pi,
            applicationNames: ["pi"],
            cliExecutableNames: ["pi"]
        ),
        LocalProviderDescriptor(
            provider: .notebookLM,
            bundleIdentifiers: ["com.google.Chrome.app.gjcmcplpgihbecacndmmbaenpfgimlec"],
            applicationNames: ["NotebookLM"],
            applicationCommandMarkers: ["--app-id=gjcmcplpgihbecacndmmbaenpfgimlec"]
        ),
        LocalProviderDescriptor(
            provider: .lmStudio,
            bundleIdentifiers: ["ai.elementlabs.lmstudio"],
            applicationNames: ["LM Studio"],
            cliExecutableNames: ["lms"]
        ),
        LocalProviderDescriptor(
            provider: .stitch,
            bundleIdentifiers: ["com.google.Chrome.app.kpkpmmpeainfoiplppkjdnclpakaldhf"],
            applicationNames: ["Stitch"],
            applicationCommandMarkers: ["--app-id=kpkpmmpeainfoiplppkjdnclpakaldhf"]
        ),
    ]
}

struct LocalApplicationSnapshot: Equatable, Sendable {
    let bundleIdentifier: String?
    let localizedName: String?
    let processID: Int32
    let isActive: Bool
    let launchedAt: Date?
}

struct LocalCommandSnapshot: Equatable, Sendable {
    let processID: Int32
    let commandLine: String
}

struct LocalActivitySnapshot: Equatable, Sendable {
    let applications: [LocalApplicationSnapshot]
    let commands: [LocalCommandSnapshot]
}

struct LocalProviderSessionScanner: Sendable {
    typealias SnapshotProvider = @Sendable () -> LocalActivitySnapshot

    let descriptor: LocalProviderDescriptor
    let snapshotProvider: SnapshotProvider

    func scan() -> [HarnessSession] {
        let snapshot = snapshotProvider()
        let applicationSessions = snapshot.applications.compactMap(applicationSession)
        let commandApplicationSessions = applicationSessions.isEmpty
            ? snapshot.commands.first(where: matchesApplicationCommand).map(applicationCommandSession)
            : nil
        let allApplicationSessions = applicationSessions + [commandApplicationSessions].compactMap { $0 }
        let applicationProcessIDs = Set(allApplicationSessions.compactMap(\.processID))
        let commandSessions: [HarnessSession] = snapshot.commands.compactMap { command in
            guard !applicationProcessIDs.contains(command.processID) else { return nil }
            return self.commandSession(command)
        }
        return allApplicationSessions + commandSessions
    }

    private func applicationSession(_ application: LocalApplicationSnapshot) -> HarnessSession? {
        guard matches(application) else { return nil }
        if descriptor.applicationPolicy == .activeOnly, !application.isActive {
            return nil
        }

        let displayName = descriptor.provider.displayName
        let applicationName = application.localizedName ?? displayName
        return HarnessSession(
            harnessID: descriptor.provider.rawValue,
            harnessDisplayName: displayName,
            sessionID: "app:\(application.processID)",
            processID: application.processID,
            cwd: "",
            title: "\(applicationName) is open",
            chatPreview: "Local application activity",
            dismissalToken: "app:\(application.processID)",
            kind: "Local application",
            entrypoint: "\(displayName) app",
            status: application.isActive ? .busy : .idle,
            replyTarget: nil,
            updatedAt: application.launchedAt,
            startedAt: application.launchedAt
        )
    }

    private func commandSession(_ command: LocalCommandSnapshot) -> HarnessSession? {
        guard !command.commandLine.contains(".app/Contents/"),
              let match = matchedCLICommand(in: command.commandLine),
              !descriptor.ignoredCLISubcommands.contains(match.subcommand)
        else { return nil }

        let displayName = descriptor.provider.displayName
        return HarnessSession(
            harnessID: descriptor.provider.rawValue,
            harnessDisplayName: displayName,
            sessionID: "cli:\(command.processID)",
            processID: command.processID,
            cwd: "",
            title: "\(displayName) CLI is running",
            chatPreview: "Local command-line activity",
            dismissalToken: "cli:\(command.processID)",
            kind: "Local command",
            entrypoint: "\(displayName) CLI",
            status: .busy,
            replyTarget: nil,
            updatedAt: nil,
            startedAt: nil
        )
    }

    private func matchesApplicationCommand(_ command: LocalCommandSnapshot) -> Bool {
        descriptor.applicationCommandMarkers.contains { marker in
            command.commandLine.contains(marker)
        }
    }

    private func applicationCommandSession(_ command: LocalCommandSnapshot) -> HarnessSession {
        let displayName = descriptor.provider.displayName
        return HarnessSession(
            harnessID: descriptor.provider.rawValue,
            harnessDisplayName: displayName,
            sessionID: "app-process:\(command.processID)",
            processID: command.processID,
            cwd: "",
            title: "\(displayName) is open",
            chatPreview: "Local installed web app activity",
            dismissalToken: "app-process:\(command.processID)",
            kind: "Local application",
            entrypoint: "\(displayName) app",
            status: .busy,
            replyTarget: nil,
            updatedAt: nil,
            startedAt: nil
        )
    }

    private func matches(_ application: LocalApplicationSnapshot) -> Bool {
        if let bundleIdentifier = application.bundleIdentifier,
           descriptor.bundleIdentifiers.contains(bundleIdentifier) {
            return true
        }
        guard let localizedName = application.localizedName else { return false }
        return descriptor.applicationNames.contains {
            $0.caseInsensitiveCompare(localizedName) == .orderedSame
        }
    }

    private func matchedCLICommand(in commandLine: String) -> (name: String, subcommand: String)? {
        let tokens = commandLine
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(4)
            .map(String.init)
        for (index, token) in tokens.enumerated() {
            let filename = URL(fileURLWithPath: token).lastPathComponent.lowercased()
            let normalized = filename.replacingOccurrences(
                of: #"\.(mjs|cjs|js)$"#,
                with: "",
                options: .regularExpression
            )
            guard descriptor.cliExecutableNames.contains(normalized) else { continue }
            let subcommand = tokens.indices.contains(index + 1)
                ? tokens[index + 1].lowercased()
                : ""
            return (normalized, subcommand)
        }
        return nil
    }
}

public struct LocalProviderHarness: PetHarness {
    public let id: String
    public let displayName: String

    private let descriptor: LocalProviderDescriptor
    private let scanner: LocalProviderSessionScanner

    init(
        descriptor: LocalProviderDescriptor,
        snapshotProvider: @escaping LocalProviderSessionScanner.SnapshotProvider
    ) {
        self.id = descriptor.provider.rawValue
        self.displayName = descriptor.provider.displayName
        self.descriptor = descriptor
        self.scanner = LocalProviderSessionScanner(
            descriptor: descriptor,
            snapshotProvider: snapshotProvider
        )
    }

    public func scan() throws -> [HarnessSession] {
        scanner.scan()
    }

    public func activate(_ session: HarnessSession) throws -> HarnessActivationResult {
        if session.kind == "Local application",
           let processID = session.processID,
           let application = NSRunningApplication(processIdentifier: processID),
           application.activate(options: []) {
            return session.sessionID.hasPrefix("app-process:")
                ? .activatedApp(appName: displayName)
                : .focusedExactTarget(appName: displayName)
        }

        guard session.kind == "Local application",
              let bundleIdentifier = descriptor.bundleIdentifiers.first
        else {
            return .unsupportedHost(processName: session.entrypoint)
        }
        return try HarnessAppActivator(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName
        ).activate()
    }

    public func sendReply(_ message: String, to session: HarnessSession) throws {
        throw PetHarnessError.replyUnsupported(provider: displayName)
    }

    static func defaultHarnesses() -> [any PetHarness] {
        let inventory = LocalActivityInventory.shared
        return LocalProviderDescriptor.defaults.map { descriptor in
            LocalProviderHarness(descriptor: descriptor) {
                inventory.snapshot()
            }
        }
    }
}

private final class LocalActivityInventory: @unchecked Sendable {
    static let shared = LocalActivityInventory()

    private let lock = NSLock()
    private var cachedSnapshot: LocalActivitySnapshot?
    private var cachedAt = Date.distantPast
    private let cacheInterval: TimeInterval = 2

    func snapshot() -> LocalActivitySnapshot {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if let cachedSnapshot, now.timeIntervalSince(cachedAt) < cacheInterval {
            return cachedSnapshot
        }

        let refreshed = LocalActivitySnapshot(
            applications: applicationSnapshots(),
            commands: commandSnapshots()
        )
        cachedSnapshot = refreshed
        cachedAt = now
        return refreshed
    }

    private func applicationSnapshots() -> [LocalApplicationSnapshot] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.activationPolicy == .regular || application.isActive else {
                return nil
            }
            return LocalApplicationSnapshot(
                bundleIdentifier: application.bundleIdentifier,
                localizedName: application.localizedName,
                processID: application.processIdentifier,
                isActive: application.isActive,
                launchedAt: application.launchDate
            )
        }
    }

    private func commandSnapshots() -> [LocalCommandSnapshot] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,args=", "-ww"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let text = String(decoding: data, as: UTF8.self)
        return text.split(whereSeparator: { $0.isNewline }).compactMap { line in
            let trimmed = line.drop(while: { $0.isWhitespace })
            guard let separator = trimmed.firstIndex(where: { $0.isWhitespace }),
                  let processID = Int32(trimmed[..<separator])
            else { return nil }
            let commandLine = trimmed[separator...]
                .drop(while: { $0.isWhitespace })
            guard !commandLine.isEmpty else { return nil }
            return LocalCommandSnapshot(
                processID: processID,
                commandLine: String(commandLine)
            )
        }
    }
}
