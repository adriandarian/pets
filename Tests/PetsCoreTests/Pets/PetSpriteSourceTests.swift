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

        #expect(source.contains("TimelineView(.animation(minimumInterval: Self.frameInterval))"))
        #expect(source.contains("private static let frameInterval = 1.0 / 30.0"))
        #expect(source.contains("animation.playbackSample(at: playbackElapsed)"))
        #expect(source.contains("secondaryFrameIndex"))
        #expect(source.contains("secondaryOpacity"))
        #expect(source.contains("PetMotionSampleModifier("))
        #expect(!source.contains("private struct PetMotionModifier"))
        #expect(source.contains("pixelatedSpriteEffect"))
        #expect(source.contains("PixelatedSpriteRasterizer(pixelation: pixelation)"))
    }

    @Test
    func petRenderersDoNotDrawSyntheticPetShadows() throws {
        let spriteSource = try source("Sources/Pets/PetSprites.swift")
        let layerSource = try source("Sources/Pets/PetLayerRenderer.swift")

        #expect(!spriteSource.contains("Ellipse()"))
        #expect(!spriteSource.contains("definition.presentation.shadowOpacity"))
        #expect(!layerSource.contains("private let shadowLayer"))
        #expect(!layerSource.contains("addSublayer(shadowLayer)"))
    }

    @Test
    func completionReactionsKeepIdlePlaybackAndAmbientMotion() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("visualContext.reaction != .error"))
        #expect(source.contains("let playbackElapsed = isAmbientMotionEnabled ? phasedElapsed : 0"))
        #expect(source.contains("sample(at: phasedElapsed, isEnabled: isAmbientMotionEnabled)"))
    }

    @Test
    func steadyAnimationUsesOneLayerBackedViewWithoutSwiftUILayoutTicks() throws {
        let spriteSource = try source("Sources/Pets/PetSprites.swift")
        let layerSource = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(spriteSource.contains("if visualContext.reaction == nil"))
        #expect(spriteSource.contains("LayerBackedAssetPetSprite("))
        #expect(layerSource.contains("struct LayerBackedAssetPetSprite: NSViewRepresentable"))
        #expect(layerSource.contains("final class PetLayerRenderView: NSView"))
        #expect(layerSource.contains("CATransaction.setDisableActions(true)"))
        #expect(layerSource.contains("animation.playbackSample(at: playbackElapsed)"))
        #expect(layerSource.contains("definition.ambientEffect.sample("))
        #expect(layerSource.contains("RunLoop.main.add(timer, forMode: .common)"))
        #expect(layerSource.contains("private let primaryImageLayer = CALayer()"))
        #expect(layerSource.contains("private let secondaryImageLayer = CALayer()"))
        #expect(layerSource.contains("private var particleLayers: [PetAmbientParticleLayer]"))
        #expect(layerSource.contains("frameLayer.update("))
        #expect(!layerSource.contains("frameLayer.setNeedsDisplay()"))
        #expect(!layerSource.contains("override func draw(in context: CGContext)"))
    }

    @Test
    func layerRendererDecodesAndDownsamplesEachSpriteAssetOnce() {
        let source = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(source.contains("import ImageIO"))
        #expect(source.contains("kCGImageSourceShouldCacheImmediately"))
        #expect(source.contains("kCGImageSourceThumbnailMaxPixelSize"))
        #expect(source.contains("maximumPixelDimension"))
        #expect(source.contains("images.setObject(image, forKey: url as NSURL)"))
        #expect(!source.contains("NSImage(contentsOf: url)"))
    }

    @Test
    func nimbusRenderersUseCleanSourceArtBeforeAddingTheAnimatedStorm() throws {
        let spriteSource = try source("Sources/Pets/PetSprites.swift")
        let layerSource = try source("Sources/Pets/PetLayerRenderer.swift")
        let sanitizerSource = (try? source(
            "Sources/PetsCore/Pets/PetArtWeatherSanitizer.swift"
        )) ?? ""

        #expect(!spriteSource.contains("PetArtWeatherSanitizer"))
        #expect(!layerSource.contains("PetArtWeatherSanitizer"))
        #expect(sanitizerSource.isEmpty)
    }

    @Test
    func nimbusRenderersDoNotRetainSpecialRuntimeCopies() throws {
        let spriteSource = try source("Sources/Pets/PetSprites.swift")
        let layerSource = try source("Sources/Pets/PetLayerRenderer.swift")

        #expect(!spriteSource.contains("retainedNimbusImages"))
        #expect(!layerSource.contains("retainedNimbusImages"))
    }

    @Test
    func layerRendererCentersEverySnowflakeArmBeforeRotatingIt() {
        let source = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(source.contains("let flakeBar = CGRect(x: -3.8, y: -0.625"))
        #expect(source.contains("CGAffineTransform(translationX: bounds.midX, y: bounds.midY)"))
        #expect(source.contains(".rotated(by: angle * .pi / 180)"))
        #expect(!source.contains(
            "CGPath(rect: centeredRect(width: 7.6, height: 1.25), transform: nil)"
        ))
    }

    @Test
    func layerRendererMirrorsTopLeftWeatherCoordinatesAcrossCoreAnimationYAxis() {
        let source = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(source.contains("- presentation.anchorY * unit"))
        #expect(source.contains("- motion.yOffset"))
        #expect(source.contains("y: (64 - sample.y) * unit"))
        #expect(source.contains("y: (128 - 97.5) * unit"))
        #expect(source.contains("centeredRect(width: 1.2, height: 1.8, x: -0.5, y: 2)"))
        #expect(!source.contains("y: (64 + sample.y) * unit"))
        #expect(source.contains("rotationAngle: -sample.rotationDegrees * .pi / 180"))
    }

    @Test
    func stormLightningExtendsDownwardInBothRenderers() {
        let canvasSource = (try? source("Sources/Pets/PetAmbientEffects.swift")) ?? ""
        let layerSource = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(canvasSource.contains("translateBy(x: 64 * unit, y: 97.5 * unit)"))
        #expect(canvasSource.contains("lightningPath(width: 20 * unit, height: 50 * unit)"))
        #expect(layerSource.contains("width: 20, height: 50"))
        #expect(layerSource.contains("y: (128 - 97.5) * unit"))
        #expect(layerSource.contains("Self.lightningPath(width: 20, height: 50)"))
    }

    @Test
    func stormLightningRemainsMountedAndPulsesThroughOpacity() {
        let source = (try? source("Sources/Pets/PetLayerRenderer.swift")) ?? ""

        #expect(source.contains("lightningLayer.isHidden = kind != .storm"))
        #expect(source.contains("lightningLayer.opacity = Float(sample.lightningIntensity)"))
        #expect(source.contains(
            "lightningLayer.shadowOpacity = Float(sample.lightningIntensity * 0.88)"
        ))
        #expect(!source.contains(
            "let showsLightning = kind == .storm && sample.lightningIntensity > 0"
        ))
    }

    @Test
    func petSpriteComposesIndependentAmbientEffectsInsideWholePetMotion() throws {
        let source = try source("Sources/Pets/PetSprites.swift")

        #expect(source.contains("definition.ambientEffect.sample("))
        #expect(source.contains("PetAmbientEffectView("))
        #expect(source.contains("layer: .background"))
        #expect(source.contains("layer: .foreground"))
        #expect(source.contains("isEnabled: isAmbientMotionEnabled"))

        let background = try #require(source.range(of: "layer: .background"))
        let body = try #require(source.range(of: "blendedPetImage("))
        let foreground = try #require(source.range(of: "layer: .foreground"))
        let wholePetMotion = try #require(source.range(of: "PetMotionSampleModifier(sample: motion)"))

        #expect(background.lowerBound < body.lowerBound)
        #expect(body.lowerBound < foreground.lowerBound)
        #expect(foreground.lowerBound < wholePetMotion.lowerBound)
    }

    @Test
    func ambientEffectViewDrawsStormWindAndSnowInOneAsynchronousCanvas() {
        let source = (try? source("Sources/Pets/PetAmbientEffects.swift")) ?? ""

        #expect(source.contains("case (.storm, .foreground)"))
        #expect(source.contains("case (.wind, .background)"))
        #expect(source.contains("case (.snow, .foreground)"))
        #expect(source.contains("Canvas(rendersAsynchronously: true)"))
        #expect(source.contains("drawStorm"))
        #expect(source.contains("drawWind"))
        #expect(source.contains("drawSnow"))
        #expect(!source.contains("ForEach(sample.particles)"))
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
