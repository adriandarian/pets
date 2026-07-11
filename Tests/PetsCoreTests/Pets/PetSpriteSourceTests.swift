import Foundation
import Testing

@Suite
struct PetSpriteSourceTests {
    @Test
    func petSpriteRoutesDefinitionsToAssetOrLegacyRenderer() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("switch definition.renderSource"))
        #expect(source.contains("AssetPetSprite("))
        #expect(source.contains("LegacyPetSpriteAdapter("))
        #expect(source.contains("PetVisualStateResolver.requestedState"))
    }

    @Test
    func petSpriteRoutesVoxelPetsToVoxelRenderer() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("case .voxel:"))
        #expect(source.contains("VoxelPetSprite(petID: petID, status: status, isExcited: isExcited)"))
    }

    @Test
    func voxelRendererDefinesAllVoxelPetsAndUsesStatusTint() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("private struct VoxelPetSprite: View"))
        #expect(source.contains("case .voxelCat:"))
        #expect(source.contains("case .voxelSlime:"))
        #expect(source.contains("case .voxelDragon:"))
        #expect(source.contains("private var statusTint: Color"))
        #expect(source.contains("statusColor(status == .unknown ? .idle : status)"))
    }

    private func source(_ path: String) throws -> String {
        let url = try repositoryRoot().appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while currentURL.path != "/" {
            if FileManager.default.fileExists(atPath: currentURL.appending(path: "Package.swift").path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
