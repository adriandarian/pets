import ClaudePetCore
import CoreGraphics
import Foundation

@MainActor
final class ClaudePetStore: ObservableObject {
    private enum DefaultsKey {
        static let petInstances = "petInstances"
        static let selectedPetInstanceID = "selectedPetInstanceID"
        static let selectedPetID = "selectedPetID"
        static let spritePixelation = "spritePixelation"
        static let sessionContextLineCount = "sessionContextLineCount"
    }

    @Published private(set) var sessions: [ClaudeSession] = []
    @Published private(set) var lastError: String?
    private(set) var lastUpdated: Date?
    @Published private(set) var isOpenAtLoginEnabled = false
    @Published private(set) var petInstances: [PetInstance]
    @Published private(set) var selectedPetInstanceID: PetInstance.ID?
    @Published private var dismissedSessions: Set<PetDismissedSession> = []

    private let scanner: ClaudeSessionScanner
    private let replySender: ClaudeReplySender
    private let sessionActivator: any SessionActivating
    private let defaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private static let refreshInterval: Duration = .seconds(5)

    init(
        scanner: ClaudeSessionScanner = ClaudeSessionScanner(),
        replySender: ClaudeReplySender = ClaudeReplySender(),
        sessionActivator: any SessionActivating = ClaudeSessionActivator(),
        defaults: UserDefaults = .standard
    ) {
        self.scanner = scanner
        self.replySender = replySender
        self.sessionActivator = sessionActivator
        self.defaults = defaults
        let persistedPetID = defaults.string(forKey: DefaultsKey.selectedPetID).map(ClaudePetID.init(rawValue:))
        let selectedPetID = persistedPetID ?? ClaudePetCatalog.defaultPetID
        let migratedPixelation = ClaudePetCatalog.pixelation(
            PetSpritePixelation.persisted(rawValue: defaults.string(forKey: DefaultsKey.spritePixelation)),
            allowedFor: selectedPetID
        )
        let persistedContextLineCount = defaults.integer(forKey: DefaultsKey.sessionContextLineCount)
        let migratedContextLineCount = PetSessionContextLineCount.clamped(
            persistedContextLineCount == 0
                ? PetSessionContextLineCount.defaultValue
                : persistedContextLineCount
        )
        let loadedPetConfiguration = Self.loadPetInstances(
            from: defaults,
            migratedPetID: selectedPetID,
            migratedPixelation: migratedPixelation,
            migratedContextLineCount: migratedContextLineCount
        )
        let loadedInstances = loadedPetConfiguration.instances
        self.petInstances = loadedInstances

        let persistedSelectedID = defaults.string(forKey: DefaultsKey.selectedPetInstanceID)
            .flatMap(UUID.init(uuidString:))
        if let persistedSelectedID, loadedInstances.contains(where: { $0.id == persistedSelectedID }) {
            self.selectedPetInstanceID = persistedSelectedID
        } else {
            self.selectedPetInstanceID = loadedInstances.first?.id
        }
        self.lastError = loadedPetConfiguration.error
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.refreshInterval)
                } catch {
                    return
                }
                await refresh()
            }
        }
    }

    var dominantStatus: ClaudeDisplayStatus {
        if visibleSessions.contains(where: { $0.displayStatus == .waiting }) {
            return .waiting
        }
        if visibleSessions.contains(where: { $0.displayStatus == .busy }) {
            return .busy
        }
        if visibleSessions.isEmpty {
            return .unknown
        }
        return .idle
    }

    var unreadChatCount: Int {
        ClaudeSession.unreadChatCount(in: visibleSessions)
    }

    var collapsedChatCount: Int {
        ClaudeSession.collapsedChatCount(in: visibleSessions)
    }

    var visibleSessions: [ClaudeSession] {
        PetDismissedSessionFilter.visibleSessions(
            sessions,
            dismissedSessions: dismissedSessions
        )
    }

    var selectedPetInstance: PetInstance? {
        guard let selectedPetInstanceID else { return nil }
        return petInstance(for: selectedPetInstanceID)
    }

    var selectedPetID: ClaudePetID? {
        selectedPetInstance?.petID
    }

    var spritePixelation: PetSpritePixelation? {
        selectedPetInstance?.pixelation
    }

    var sessionContextLineCount: Int? {
        selectedPetInstance?.sessionContextLineCount
    }

    var isPetVisible: Bool {
        areAnyPetsVisible
    }

    var areAnyPetsVisible: Bool {
        petInstances.contains(where: \.isVisible)
    }

    var visiblePetInstances: [PetInstance] {
        petInstances.filter(\.isVisible)
    }

    func petInstance(for id: PetInstance.ID) -> PetInstance? {
        petInstances.first(where: { $0.id == id })
    }

    func addPet() {
        var instance = PetInstance.defaultInstance()
        instance.name = uniquePetName(baseName: instance.name)
        petInstances.append(instance)
        selectedPetInstanceID = instance.id
        persistPetInstances()
        persistSelectedPetInstanceID()
    }

    func duplicateSelectedPet() {
        guard var instance = selectedPetInstance else { return }
        instance.id = UUID()
        instance.name = uniquePetName(baseName: instance.name)
        petInstances.append(instance)
        selectedPetInstanceID = instance.id
        persistPetInstances()
        persistSelectedPetInstanceID()
    }

    func updatePetVisibility(_ isVisible: Bool) {
        setAllPetsVisible(isVisible)
    }

    func setAllPetsVisible(_ isVisible: Bool) {
        guard petInstances.contains(where: { $0.isVisible != isVisible }) else { return }
        for index in petInstances.indices {
            petInstances[index].isVisible = isVisible
        }
        persistPetInstances()
    }

    func updatePetVisibility(_ id: PetInstance.ID, isVisible: Bool) {
        updatePet(id) { pet in
            pet.isVisible = isVisible
        }
    }

    func updateOpenAtLoginEnabled(_ isEnabled: Bool) {
        guard isOpenAtLoginEnabled != isEnabled else { return }
        isOpenAtLoginEnabled = isEnabled
    }

    func selectPet(_ petID: ClaudePetID) {
        updateSelectedPetID(petID)
    }

    func updateSpritePixelation(_ requestedPixelation: PetSpritePixelation) {
        updateSelectedPetPixelation(requestedPixelation)
    }

    func updateSessionContextLineCount(_ requestedLineCount: Int) {
        updateSelectedPetContextLineCount(requestedLineCount)
    }

    func removeSelectedPet() {
        guard let selectedPetInstanceID else { return }
        petInstances.removeAll { $0.id == selectedPetInstanceID }
        self.selectedPetInstanceID = petInstances.first?.id
        persistSelectedPetInstanceID()
        persistPetInstances()
    }

    func selectPetInstance(_ id: PetInstance.ID) {
        guard selectedPetInstanceID != id,
              petInstances.contains(where: { $0.id == id })
        else { return }
        selectedPetInstanceID = id
        persistSelectedPetInstanceID()
    }

    func updateSelectedPetName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSelectedPet { pet in
            pet.name = trimmedName.isEmpty
                ? ClaudePetCatalog.displayName(for: pet.petID)
                : trimmedName
        }
    }

    func updateSelectedPetID(_ petID: ClaudePetID) {
        updateSelectedPet { pet in
            pet.updatePetID(petID)
            if pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pet.name = ClaudePetCatalog.displayName(for: petID)
            }
        }
    }

    func updateSelectedPetPixelation(_ pixelation: PetSpritePixelation) {
        updateSelectedPet { pet in
            pet.updatePixelation(pixelation)
        }
    }

    func updateSelectedPetContextLineCount(_ lineCount: Int) {
        updateSelectedPet { pet in
            pet.updateSessionContextLineCount(lineCount)
        }
    }

    func updateSelectedPetAnimationSettings(_ settings: PetAnimationSettings) {
        updateSelectedPet { pet in
            pet.animationSettings = settings
        }
    }

    func updatePetOverlayPosition(
        _ id: PetInstance.ID,
        origin: CGPoint,
        placement: PetOverlayHorizontalPlacement
    ) {
        updatePet(id) { pet in
            pet.overlayPosition = PetOverlayPosition(
                origin: origin,
                horizontalPlacement: placement
            )
        }
    }

    func recordError(_ error: String) {
        lastError = error
        lastUpdated = Date()
    }

    func dismissSession(_ session: ClaudeSession) {
        dismissedSessions.insert(PetDismissedSession(session: session))
    }

    func activateSession(_ session: ClaudeSession) {
        let sessionActivator = self.sessionActivator
        Task {
            do {
                let result = try await Task.detached {
                    try sessionActivator.activate(session)
                }.value
                applyActivationResult(result)
            } catch {
                lastError = error.localizedDescription
                lastUpdated = Date()
            }
        }
    }

    func sendReply(_ message: String, to session: ClaudeSession) {
        let replySender = self.replySender
        Task {
            do {
                try await Task.detached {
                    try replySender.send(message, to: session)
                }.value
                lastError = nil
                await refresh()
            } catch {
                lastError = error.localizedDescription
                lastUpdated = Date()
            }
        }
    }

    private func refresh() async {
        let scanner = scanner
        do {
            let scannedSessions = try await Task.detached(priority: .utility) {
                try scanner.scan()
            }.value
            guard !Task.isCancelled else { return }
            applyRefreshResult(sessions: scannedSessions, error: nil)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            applyRefreshResult(sessions: nil, error: error.localizedDescription)
        }
    }

    private func applyRefreshResult(sessions scannedSessions: [ClaudeSession]?, error: String?) {
        if let scannedSessions, sessions != scannedSessions {
            sessions = scannedSessions
            dismissedSessions.formIntersection(scannedSessions.map(PetDismissedSession.init))
        }
        if lastError != error {
            lastError = error
        }
        lastUpdated = Date()
    }

    private func applyActivationResult(_ result: ClaudeSessionActivationResult) {
        switch result {
        case .focusedExactTarget, .activatedApp:
            lastError = nil
        case let .unsupportedHost(processName):
            lastError = "Could not find a supported app for \(processName ?? "this Claude session")."
        case let .permissionDenied(reason):
            lastError = reason
        }
        lastUpdated = Date()
    }

    private static func loadPetInstances(
        from defaults: UserDefaults,
        migratedPetID: ClaudePetID,
        migratedPixelation: PetSpritePixelation,
        migratedContextLineCount: Int
    ) -> (instances: [PetInstance], error: String?) {
        if let data = defaults.data(forKey: DefaultsKey.petInstances) {
            do {
                let decoded = try JSONDecoder().decode([PetInstance].self, from: data)
                return (decoded.map(normalizedCloudFamilyInstance), nil)
            } catch {
                return (
                    [],
                    "Pet settings could not be loaded. Defaults were restored."
                )
            }
        }

        return ([], nil)
    }

    private static func normalizedCloudFamilyInstance(_ instance: PetInstance) -> PetInstance {
        guard instance.petID == .classicClaude,
              instance.name == ClaudePetCatalog.displayName(for: .classicClaude)
        else { return instance }

        var normalized = instance
        normalized.name = "Classic Claude"
        return normalized
    }

    private func updateSelectedPet(_ mutate: (inout PetInstance) -> Void) {
        guard let selectedPetInstanceID else { return }
        updatePet(selectedPetInstanceID, mutate)
    }

    private func updatePet(
        _ id: PetInstance.ID,
        _ mutate: (inout PetInstance) -> Void
    ) {
        guard let index = petInstances.firstIndex(where: { $0.id == id }) else { return }
        var pet = petInstances[index]
        mutate(&pet)
        pet.updatePetID(pet.petID)
        pet.updateSessionContextLineCount(pet.sessionContextLineCount)
        guard petInstances[index] != pet else { return }
        petInstances[index] = pet
        persistPetInstances()
    }

    private func persistPetInstances() {
        guard let data = try? JSONEncoder().encode(petInstances) else { return }
        defaults.set(data, forKey: DefaultsKey.petInstances)
    }

    private func persistSelectedPetInstanceID() {
        if let selectedPetInstanceID {
            defaults.set(selectedPetInstanceID.uuidString, forKey: DefaultsKey.selectedPetInstanceID)
        } else {
            defaults.removeObject(forKey: DefaultsKey.selectedPetInstanceID)
        }
    }

    private func uniquePetName(baseName: String) -> String {
        let existingNames = Set(petInstances.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = petInstances.count + 1
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }
}
