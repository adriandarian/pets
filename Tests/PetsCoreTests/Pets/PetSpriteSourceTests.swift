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
    func petSpriteBlendsFramesBeforeOneAmbientTransform() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("animation.playbackSample(at: playbackElapsed)"))
        #expect(source.contains("secondaryFrameIndex"))
        #expect(source.contains("secondaryOpacity"))
        #expect(source.contains("PetMotionSampleModifier("))
        #expect(source.contains("shadowScale"))
        #expect(source.contains("shadowOpacityMultiplier"))
        #expect(!source.contains("private struct PetMotionModifier"))
        #expect(source.contains("pixelatedSpriteEffect"))
        #expect(source.contains("PixelatedSpriteRasterizer(pixelation: pixelation)"))
    }

    @Test
    func reactionsFreezeIdlePlaybackAndAmbientMotion() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("visualContext.reaction == nil"))
        #expect(source.contains("let playbackElapsed = isAmbientMotionEnabled ? phasedElapsed : 0"))
        #expect(source.contains("sample(at: phasedElapsed, isEnabled: isAmbientMotionEnabled)"))
    }

    @Test
    func petSpriteAppliesTransparentReactionTreatmentsBeforePixelation() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("PetReactionVisualModifier("))
        #expect(source.contains("reaction: visualContext.reaction"))
        #expect(source.contains("LinearGradient("))
        #expect(source.contains(".mask(content)"))
        #expect(source.contains(".saturation(0.28)"))
        #expect(source.contains(".brightness(-0.18)"))
        #expect(source.contains("visualContext.reaction != nil"))

        let reactionModifier = try #require(source.range(of: "private struct PetReactionVisualModifier"))
        let pixelation = try #require(source.range(of: "private extension View"))
        #expect(reactionModifier.lowerBound < pixelation.lowerBound)
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
