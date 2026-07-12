import PetsCore
import CoreGraphics
import Foundation

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var sessions: [HarnessSession] = []
    @Published private(set) var lastError: String?
    private(set) var lastUpdated: Date?
    @Published private(set) var isOpenAtLoginEnabled = false
    @Published private(set) var petInstances: [PetInstance]
    @Published private(set) var selectedPetInstanceID: PetInstance.ID?
    @Published private var dismissedSessions: Set<PetDismissedSession> = []

    private let harness: any PetHarness
    private let settingsPersistence: PetSettingsPersistence
    private var refreshTask: Task<Void, Never>?
    private static let refreshInterval: Duration = .seconds(5)

    init(
        harness: any PetHarness = ClaudeHarness(),
        defaults: UserDefaults = .standard
    ) {
        self.harness = harness
        self.settingsPersistence = PetSettingsPersistence(defaults: defaults)
        let loadedPetConfiguration = settingsPersistence.loadPetConfiguration()
        let loadedInstances = loadedPetConfiguration.instances
        self.petInstances = loadedInstances
        self.selectedPetInstanceID = loadedPetConfiguration.selectedID
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

    var dominantStatus: HarnessSessionStatus {
        if visibleSessions.contains(where: { $0.status == .waiting }) {
            return .waiting
        }
        if visibleSessions.contains(where: { $0.status == .busy }) {
            return .busy
        }
        if visibleSessions.isEmpty {
            return .unknown
        }
        return .idle
    }

    var unreadChatCount: Int {
        HarnessSession.unreadChatCount(in: visibleSessions)
    }

    var collapsedChatCount: Int {
        HarnessSession.collapsedChatCount(in: visibleSessions)
    }

    var visibleSessions: [HarnessSession] {
        PetDismissedSessionFilter.visibleSessions(
            sessions,
            dismissedSessions: dismissedSessions
        )
    }

    var selectedPetInstance: PetInstance? {
        guard let selectedPetInstanceID else { return nil }
        return petInstance(for: selectedPetInstanceID)
    }

    var selectedPetID: PetID? {
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
                ? PetCatalog.displayName(for: pet.petID)
                : trimmedName
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

    func dismissSession(_ session: HarnessSession) {
        dismissedSessions.insert(PetDismissedSession(session: session))
    }

    func activateSession(_ session: HarnessSession) {
        let harness = self.harness
        Task {
            do {
                let result = try await Task.detached {
                    try harness.activate(session)
                }.value
                applyActivationResult(result)
            } catch {
                lastError = error.localizedDescription
                lastUpdated = Date()
            }
        }
    }

    func sendReply(_ message: String, to session: HarnessSession) {
        let harness = self.harness
        Task {
            do {
                try await Task.detached {
                    try harness.sendReply(message, to: session)
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
        let harness = harness
        do {
            let scannedSessions = try await Task.detached(priority: .utility) {
                try harness.scan()
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

    private func applyRefreshResult(sessions scannedSessions: [HarnessSession]?, error: String?) {
        if let scannedSessions, sessions != scannedSessions {
            sessions = scannedSessions
            dismissedSessions.formIntersection(scannedSessions.map(PetDismissedSession.init))
        }
        if lastError != error {
            lastError = error
        }
        lastUpdated = Date()
    }

    private func applyActivationResult(_ result: HarnessActivationResult) {
        switch result {
        case .focusedExactTarget, .activatedApp:
            lastError = nil
        case let .unsupportedHost(processName):
            lastError = "Could not find a supported app for \(processName ?? "this session")."
        case let .permissionDenied(reason):
            lastError = reason
        }
        lastUpdated = Date()
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
        settingsPersistence.persistPetInstances(petInstances)
    }

    private func persistSelectedPetInstanceID() {
        settingsPersistence.persistSelectedPetInstanceID(selectedPetInstanceID)
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
