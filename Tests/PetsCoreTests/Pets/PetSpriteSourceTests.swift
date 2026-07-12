import Foundation
import Testing

@Suite
struct PetSpriteSourceTests {
    @Test
    func petSpriteUsesOnlyGeneratedAssetRenderer() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("AssetPetSprite("))
        #expect(source.contains("PetVisualStateResolver.requestedState"))
        #expect(!source.contains("LegacyPetSpriteAdapter"))
        #expect(!source.contains("CloudFamilySprite"))
        #expect(!source.contains("WorkspacePetSprite"))
        #expect(!source.contains("NaturePetSprite"))
        #expect(!source.contains("CozyPetSprite"))
        #expect(!source.contains("VoxelPetSprite"))
    }

    @Test
    func petSpriteRetainsFramePlaybackMotionAndPixelation() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("animation.frameIndex(at: elapsed)"))
        #expect(source.contains("PetMotionModifier("))
        #expect(source.contains("pixelatedSpriteEffect"))
        #expect(source.contains("PixelatedSpriteRasterizer(pixelation: pixelation)"))
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
