import PetsCore
import CoreGraphics
import Foundation

struct PetUsageSourceStatus: Identifiable, Equatable {
    let id: String
    let displayName: String
    var tokens: Int64?
    var periodID: String?
    var errorMessage: String?
    var updatedAt: Date?
}

private struct PetUsageSourceResult: Sendable {
    let id: String
    let displayName: String
    let reading: PetUsageReading?
    let errorMessage: String?
}

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var sessions: [HarnessSession] = []
    @Published private(set) var lastError: String?
    @Published private(set) var currentReaction: PetReaction?
    private(set) var lastUpdated: Date?
    @Published private(set) var isOpenAtLoginEnabled = false
    @Published private(set) var petInstances: [PetInstance]
    @Published private(set) var selectedPetInstanceID: PetInstance.ID?
    @Published private(set) var collectionState: PetCollectionState
    @Published private(set) var usageSourceStatuses: [PetUsageSourceStatus]
    @Published private(set) var isRefreshingRewardUsage = false
    @Published private(set) var unlockedPetID: PetID?
    @Published private(set) var collectionError: String?
    @Published private var dismissedSessions: Set<PetDismissedSession> = []

    private let harness: any PetHarness
    private let settingsPersistence: PetSettingsPersistence
    private let collectionPersistence: PetCollectionPersistence
    private let usageSources: [any PetUsageSource]
    private var refreshTask: Task<Void, Never>?
    private var rewardRefreshTask: Task<Void, Never>?
    private var manualRewardRefreshTask: Task<Void, Never>?
    private var sessionObservationCoordinator = PetSessionObservationCoordinator()
    private var completionReactionTask: Task<Void, Never>?
    private var completionReactionExpiry = PetCompletionReactionExpiry()
    private static let refreshInterval: Duration = .seconds(5)
    private static let rewardRefreshInterval: Duration = .seconds(15 * 60)
    private static let completionReactionDuration: Duration = .seconds(4)

    init(
        harness: any PetHarness = ClaudeHarness(),
        defaults: UserDefaults = .standard,
        usageSources: [any PetUsageSource] = [BuildCLIUsageSource(), CodexUsageSource()]
    ) {
        self.harness = harness
        self.settingsPersistence = PetSettingsPersistence(defaults: defaults)
        self.collectionPersistence = PetCollectionPersistence(defaults: defaults)
        self.usageSources = usageSources
        let loadedPetConfiguration = settingsPersistence.loadPetConfiguration()
        let loadedInstances = loadedPetConfiguration.instances
        let loadedCollection = collectionPersistence.load(
            grandfathering: loadedInstances.map(\.petID)
        )
        self.petInstances = loadedInstances
        self.selectedPetInstanceID = loadedPetConfiguration.selectedID
        self.collectionState = loadedCollection.state
        self.collectionError = loadedCollection.error
        self.usageSourceStatuses = usageSources.map { source in
            let checkpoint = loadedCollection.state.providerCheckpoints[source.id]
            return PetUsageSourceStatus(
                id: source.id,
                displayName: source.displayName,
                tokens: checkpoint?.observedTokens,
                periodID: checkpoint?.periodID,
                errorMessage: nil,
                updatedAt: nil
            )
        }
        self.lastError = loadedPetConfiguration.error
        self.currentReaction = loadedPetConfiguration.error == nil ? nil : .error
        self.sessionObservationCoordinator.recordError(loadedPetConfiguration.error)
    }

    deinit {
        refreshTask?.cancel()
        rewardRefreshTask?.cancel()
        manualRewardRefreshTask?.cancel()
        completionReactionTask?.cancel()
    }

    func start() {
        if refreshTask == nil {
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

        if rewardRefreshTask == nil {
            rewardRefreshTask = Task { [weak self] in
                guard let self else { return }
                await performRewardRefresh()

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: Self.rewardRefreshInterval)
                    } catch {
                        return
                    }
                    await performRewardRefresh()
                }
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
        addPet(petID: PetCatalog.defaultPetID)
    }

    func addPet(petID: PetID) {
        guard isPetOwned(petID) else { return }
        guard let definition = PetCatalog.definition(for: petID) else { return }
        var instance = PetInstance(
            name: definition.displayName,
            petID: definition.id,
            pixelation: definition.defaults.pixelation,
            sessionContextLineCount: definition.defaults.sessionContextLineCount,
            animationSettings: definition.defaults.animationSettings
        )
        instance.name = uniquePetName(baseName: instance.name)
        petInstances.append(instance)
        selectedPetInstanceID = instance.id
        persistPetInstances()
        persistSelectedPetInstanceID()
    }

    func duplicatePet(_ id: PetInstance.ID) {
        guard var instance = petInstance(for: id) else { return }
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

    func selectPet(_ petID: PetID) {
        updateSelectedPetID(petID)
    }

    func updateSessionContextLineCount(_ requestedLineCount: Int) {
        updateSelectedPetContextLineCount(requestedLineCount)
    }

    func removePet(_ id: PetInstance.ID) {
        guard let index = petInstances.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedPetInstanceID == id
        petInstances.remove(at: index)
        if wasSelected {
            selectedPetInstanceID = petInstances.first?.id
        }
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

    func updatePetName(_ id: PetInstance.ID, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatePet(id) { pet in
            pet.name = trimmedName.isEmpty
                ? PetCatalog.displayName(for: pet.petID)
                : trimmedName
        }
    }

    func updateSelectedPetName(_ name: String) {
        guard let selectedPetInstanceID else { return }
        updatePetName(selectedPetInstanceID, name: name)
    }

    func updateSelectedPetID(_ petID: PetID) {
        guard isPetOwned(petID) else { return }
        updateSelectedPet { pet in
            pet.changePetID(petID)
        }
    }

    func isPetOwned(_ petID: PetID) -> Bool {
        collectionState.ownedPetIDs.contains(PetCatalog.resolvedPetID(petID))
    }

    func unownedPetIDs(for rarity: PetRarity) -> [PetID] {
        collectionState.unownedPetIDs(
            for: rarity,
            eligiblePetIDs: PetCatalog.petIDs(for: rarity)
        )
    }

    func refreshRewardUsage() {
        guard manualRewardRefreshTask == nil, !isRefreshingRewardUsage else { return }
        manualRewardRefreshTask = Task { [weak self] in
            guard let self else { return }
            await performRewardRefresh()
            manualRewardRefreshTask = nil
        }
    }

    func openChest(_ rarity: PetRarity) {
        var updatedState = collectionState
        let candidates = updatedState.unownedPetIDs(
            for: rarity,
            eligiblePetIDs: PetCatalog.petIDs(for: rarity)
        )
        let selectionIndex = candidates.isEmpty ? 0 : Int.random(in: candidates.indices)

        do {
            let petID = try updatedState.openChest(
                rarity: rarity,
                eligiblePetIDs: PetCatalog.petIDs(for: rarity),
                selectionIndex: selectionIndex
            )
            collectionState = updatedState
            unlockedPetID = petID
            collectionError = nil
            collectionPersistence.persist(updatedState)
        } catch {
            collectionError = error.localizedDescription
        }
    }

    func dismissUnlockedPet() {
        unlockedPetID = nil
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
        setLastError(error)
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
                setLastError(error.localizedDescription)
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
                setLastError(nil)
                await refresh()
            } catch {
                setLastError(error.localizedDescription)
                lastUpdated = Date()
            }
        }
    }

    private func performRewardRefresh() async {
        guard !isRefreshingRewardUsage else { return }
        isRefreshingRewardUsage = true
        defer { isRefreshingRewardUsage = false }

        let sources = usageSources
        let results = await Task.detached(priority: .utility) {
            sources.map { source in
                do {
                    return PetUsageSourceResult(
                        id: source.id,
                        displayName: source.displayName,
                        reading: try source.read(),
                        errorMessage: nil
                    )
                } catch {
                    return PetUsageSourceResult(
                        id: source.id,
                        displayName: source.displayName,
                        reading: nil,
                        errorMessage: error.localizedDescription
                    )
                }
            }
        }.value
        guard !Task.isCancelled else { return }

        let refreshedAt = Date()
        var updatedState = collectionState
        var hadSuccessfulReading = false
        usageSourceStatuses = results.map { result in
            if let reading = result.reading {
                hadSuccessfulReading = true
                _ = updatedState.apply(reading)
                return PetUsageSourceStatus(
                    id: result.id,
                    displayName: result.displayName,
                    tokens: reading.tokens,
                    periodID: reading.periodID,
                    errorMessage: nil,
                    updatedAt: refreshedAt
                )
            }

            let previous = usageSourceStatuses.first { $0.id == result.id }
            return PetUsageSourceStatus(
                id: result.id,
                displayName: result.displayName,
                tokens: previous?.tokens,
                periodID: previous?.periodID,
                errorMessage: result.errorMessage,
                updatedAt: refreshedAt
            )
        }

        if updatedState != collectionState {
            collectionState = updatedState
            collectionPersistence.persist(updatedState)
        }
        if hadSuccessfulReading {
            collectionError = nil
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
        if let scannedSessions {
            let didCompleteSession = sessionObservationCoordinator
                .observeSuccessfulSessions(scannedSessions)
            if sessions != scannedSessions {
                sessions = scannedSessions
                dismissedSessions.formIntersection(scannedSessions.map(PetDismissedSession.init))
            }

            setLastError(error)
            if error == nil, didCompleteSession {
                beginCompletionReaction()
            }
        } else {
            setLastError(error)
        }
        lastUpdated = Date()
    }

    private func applyActivationResult(_ result: HarnessActivationResult) {
        switch result {
        case .focusedExactTarget, .activatedApp:
            setLastError(nil)
        case let .unsupportedHost(processName):
            setLastError("Could not find a supported app for \(processName ?? "this session").")
        case let .permissionDenied(reason):
            setLastError(reason)
        }
        lastUpdated = Date()
    }

    private func setLastError(_ error: String?) {
        sessionObservationCoordinator.recordError(error)

        if error != nil {
            completionReactionTask?.cancel()
            completionReactionTask = nil
            completionReactionExpiry.cancel()
            currentReaction = .error
        } else if currentReaction == .error {
            currentReaction = nil
        }

        if lastError != error {
            lastError = error
        }
    }

    private func beginCompletionReaction() {
        completionReactionTask?.cancel()
        let generation = completionReactionExpiry.restart()
        currentReaction = .completion

        completionReactionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.completionReactionDuration)
            } catch {
                return
            }

            guard let self, self.currentReaction == .completion else { return }
            guard self.completionReactionExpiry.invalidate(ifCurrent: generation) else { return }
            self.currentReaction = nil
            self.completionReactionTask = nil
        }
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
