import Foundation
import Testing

@Suite
struct PetCollectionViewSourceTests {
    @Test
    func settingsExposeCollectionAsAThirdNativeTab() throws {
        let source = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(source.contains("case collection"))
        #expect(source.contains("PetCollectionView(store: store)"))
        #expect(source.contains("Label(\"Collection\", systemImage: \"square.grid.2x2\")"))
    }

    @Test
    func collectionHubContainsTheCoreRewardJourney() throws {
        let source = try source("Sources/Pets/PetCollectionViews.swift")

        #expect(source.contains("struct PetCollectionView: View"))
        #expect(source.contains("ProgressView(value: store.collectionState.progressFraction)"))
        #expect(source.contains("store.refreshRewardUsage()"))
        #expect(source.contains("ForEach(PetRarity.allCases"))
        #expect(source.contains("store.openChest(rarity)"))
        #expect(source.contains("PetArtResourceLocator.url(for:"))
        #expect(source.contains("\"Pet Collection\""))
        #expect(source.contains("store.addPet(petID: petID)"))
        #expect(source.contains("UnlockedPetSheet"))
    }

    @Test
    func spritePickerShowsLockedSpeciesButCannotSelectThem() throws {
        let source = try source("Sources/Pets/PetSettingsViews.swift")

        #expect(source.contains("isOwned: store.isPetOwned(petID)"))
        #expect(source.contains(".disabled(!isOwned)"))
        #expect(source.contains("Label(\"Locked\", systemImage: \"lock.fill\")"))
    }

    private func source(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/" {
            if FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path) {
                return try String(contentsOf: root.appending(path: path), encoding: .utf8)
            }
            root.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
