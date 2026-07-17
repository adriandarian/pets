import AppKit
import ImageIO
import PetsCore
import QuartzCore
import SwiftUI

struct LayerBackedAssetPetSprite: NSViewRepresentable {
    let definition: PetDefinition
    let artPack: PetArtPack
    let visualContext: PetVisualContext

    func makeNSView(context: Context) -> PetLayerRenderView {
        PetLayerRenderView(
            definition: definition,
            artPack: artPack,
            visualContext: visualContext
        )
    }

    func updateNSView(_ nsView: PetLayerRenderView, context: Context) {
        nsView.update(
            definition: definition,
            artPack: artPack,
            visualContext: visualContext
        )
    }

    static func dismantleNSView(_ nsView: PetLayerRenderView, coordinator: ()) {
        nsView.stopAnimating()
    }
}

@MainActor
final class PetLayerRenderView: NSView {
    private static let frameInterval = 1.0 / 30.0

    private var definition: PetDefinition
    private var artPack: PetArtPack
    private var visualContext: PetVisualContext
    private var animationTimer: Timer?

    init(
        definition: PetDefinition,
        artPack: PetArtPack,
        visualContext: PetVisualContext
    ) {
        self.definition = definition
        self.artPack = artPack
        self.visualContext = visualContext
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    override func makeBackingLayer() -> CALayer {
        PetFrameLayer()
    }

    override func layout() {
        super.layout()
        layer?.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        render(at: Date())
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimating()
        } else {
            render(at: Date())
            updateAnimationTimer()
        }
    }

    func update(
        definition: PetDefinition,
        artPack: PetArtPack,
        visualContext: PetVisualContext
    ) {
        self.definition = definition
        self.artPack = artPack
        self.visualContext = visualContext
        render(at: Date())
        updateAnimationTimer()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private var requestedState: PetVisualState {
        PetVisualStateResolver.requestedState(for: visualContext)
    }

    private var animation: PetAnimation {
        artPack.resolvedAnimation(for: requestedState)
    }

    private var needsContinuousUpdates: Bool {
        visualContext.animationSettings.isIdleMotionEnabled
            && (
                animation.frames.count > 1
                    || animation.motion != .none
                    || definition.ambientEffect != .none
            )
    }

    private func updateAnimationTimer() {
        guard window != nil, needsContinuousUpdates else {
            stopAnimating()
            return
        }
        guard animationTimer == nil else { return }

        let timer = Timer(
            timeInterval: Self.frameInterval,
            target: self,
            selector: #selector(animationTimerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = Self.frameInterval * 0.15
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc
    private func animationTimerDidFire(_ timer: Timer) {
        render(at: Date())
    }

    private func render(at date: Date) {
        guard bounds.width > 1, bounds.height > 1,
              let frameLayer = layer as? PetFrameLayer
        else {
            return
        }

        let animation = animation
        let rawElapsed = date.timeIntervalSinceReferenceDate
        let isAmbientMotionEnabled = visualContext.animationSettings.isIdleMotionEnabled
        let playbackElapsed = isAmbientMotionEnabled
            ? rawElapsed + animation.totalDuration * visualContext.animationPhaseOffset
            : 0
        let playback = animation.playbackSample(at: playbackElapsed)
        let primaryFrame = animation.frames[playback.primaryFrameIndex]
        let secondaryFrame = playback.secondaryFrameIndex.map { animation.frames[$0] }
        guard let primaryImage = PetLayerImageCache.shared.image(for: primaryFrame) else {
            return
        }

        let motionElapsed = rawElapsed
            + animation.motion.cycleDuration * visualContext.animationPhaseOffset
        let motion = animation.motion.sample(
            at: motionElapsed,
            isEnabled: isAmbientMotionEnabled
        )
        let ambient = definition.ambientEffect.sample(
            at: rawElapsed,
            phaseOffset: visualContext.animationPhaseOffset,
            isEnabled: isAmbientMotionEnabled
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frameLayer.update(
            primaryImage: primaryImage,
            secondaryImage: secondaryFrame.flatMap(PetLayerImageCache.shared.image(for:)),
            secondaryOpacity: playback.secondaryOpacity,
            presentation: definition.presentation,
            motion: motion,
            ambientKind: definition.ambientEffect,
            ambientSample: ambient,
            in: bounds,
            contentsScale: window?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 2
        )
        CATransaction.commit()
    }
}

@MainActor
private final class PetLayerImageCache {
    static let shared = PetLayerImageCache()

    private let maximumPixelDimension = 384
    private let images = NSCache<NSURL, CGImage>()

    func image(for frame: PetAnimationFrame) -> CGImage? {
        guard let url = PetArtResourceLocator.url(for: frame) else { return nil }
        if let cached = images.object(forKey: url as NSURL) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: true] as CFDictionary
        ),
              let image = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceShouldCacheImmediately: true,
                      kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
                  ] as CFDictionary
              )
        else {
            return nil
        }
        images.setObject(image, forKey: url as NSURL)
        return image
    }
}

private final class PetFrameLayer: CALayer {
    private let contentLayer = CALayer()
    private let backgroundAmbientLayer = CALayer()
    private let primaryImageLayer = CALayer()
    private let secondaryImageLayer = CALayer()
    private let foregroundAmbientLayer = CALayer()
    private let lightningLayer = CAShapeLayer()
    private var particleLayers: [PetAmbientParticleLayer] = []
    private var configuredAmbientKind: PetAmbientEffectKind = .none

    override init() {
        super.init()
        configureLayerTree()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        configureLayerTree()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(
        primaryImage: CGImage,
        secondaryImage: CGImage?,
        secondaryOpacity: Double,
        presentation: PetPresentationConfiguration,
        motion: PetMotionSample,
        ambientKind: PetAmbientEffectKind,
        ambientSample: PetAmbientEffectSample,
        in renderBounds: CGRect,
        contentsScale: CGFloat
    ) {
        let side = min(renderBounds.width, renderBounds.height)
        let unit = side / 128
        let center = CGPoint(x: renderBounds.midX, y: renderBounds.midY)

        frame = renderBounds
        self.contentsScale = contentsScale

        let contentBounds = CGRect(x: 0, y: 0, width: side, height: side)
        contentLayer.bounds = contentBounds
        contentLayer.position = CGPoint(
            x: center.x + presentation.anchorX * unit + motion.xOffset,
            y: center.y
                - presentation.anchorY * unit
                - motion.yOffset
        )
        let scale = presentation.contentScale * motion.scale
        contentLayer.setAffineTransform(
            CGAffineTransform(rotationAngle: -motion.rotationDegrees * .pi / 180)
                .scaledBy(x: scale, y: scale)
        )

        for imageLayer in [primaryImageLayer, secondaryImageLayer] {
            imageLayer.frame = contentBounds
            imageLayer.contentsScale = contentsScale
        }
        backgroundAmbientLayer.frame = contentBounds
        foregroundAmbientLayer.frame = contentBounds
        primaryImageLayer.contents = primaryImage
        secondaryImageLayer.contents = secondaryImage
        secondaryImageLayer.opacity = secondaryImage == nil ? 0 : Float(secondaryOpacity)

        updateAmbientLayers(
            kind: ambientKind,
            sample: ambientSample,
            unit: unit,
            contentsScale: contentsScale
        )
    }

    private func configureLayerTree() {
        backgroundColor = NSColor.clear.cgColor
        isOpaque = false
        isGeometryFlipped = true

        contentLayer.actions = disabledLayerActions()
        backgroundAmbientLayer.actions = disabledLayerActions()
        primaryImageLayer.actions = disabledLayerActions()
        secondaryImageLayer.actions = disabledLayerActions()
        foregroundAmbientLayer.actions = disabledLayerActions()
        lightningLayer.actions = disabledLayerActions()

        primaryImageLayer.contentsGravity = .resizeAspect
        secondaryImageLayer.contentsGravity = .resizeAspect
        primaryImageLayer.minificationFilter = .trilinear
        secondaryImageLayer.minificationFilter = .trilinear
        lightningLayer.fillColor = NSColor(
            calibratedRed: 1.0,
            green: 0.77,
            blue: 0.20,
            alpha: 1
        ).cgColor
        lightningLayer.shadowColor = NSColor(
            calibratedRed: 1.0,
            green: 0.68,
            blue: 0.12,
            alpha: 1
        ).cgColor
        lightningLayer.shadowOffset = .zero
        lightningLayer.shadowRadius = 4

        addSublayer(contentLayer)
        contentLayer.addSublayer(backgroundAmbientLayer)
        contentLayer.addSublayer(primaryImageLayer)
        contentLayer.addSublayer(secondaryImageLayer)
        contentLayer.addSublayer(foregroundAmbientLayer)
        foregroundAmbientLayer.addSublayer(lightningLayer)
    }

    private func updateAmbientLayers(
        kind: PetAmbientEffectKind,
        sample: PetAmbientEffectSample,
        unit: CGFloat,
        contentsScale: CGFloat
    ) {
        if kind != configuredAmbientKind || particleLayers.count != sample.particles.count {
            particleLayers.forEach { $0.removeFromSuperlayer() }
            particleLayers = sample.particles.map { particle in
                let layer = PetAmbientParticleLayer(kind: kind, stretch: particle.stretch)
                layer.contentsScale = contentsScale
                return layer
            }
            let container = kind == .wind ? backgroundAmbientLayer : foregroundAmbientLayer
            particleLayers.forEach(container.addSublayer)
            configuredAmbientKind = kind
        }

        for (layer, particle) in zip(particleLayers, sample.particles) {
            layer.update(
                kind: kind,
                sample: particle,
                unit: unit,
                contentsScale: contentsScale
            )
        }

        lightningLayer.isHidden = kind != .storm
        if kind == .storm {
            let lightningScale = unit * (0.94 + sample.lightningIntensity * 0.10)
            lightningLayer.bounds = CGRect(x: 0, y: 0, width: 20, height: 50)
            lightningLayer.position = CGPoint(x: 64 * unit, y: (128 - 97.5) * unit)
            lightningLayer.path = Self.lightningPath(width: 20, height: 50)
            lightningLayer.opacity = Float(sample.lightningIntensity)
            lightningLayer.shadowOpacity = Float(sample.lightningIntensity * 0.88)
            lightningLayer.setAffineTransform(
                CGAffineTransform(scaleX: lightningScale, y: lightningScale)
            )
        }
    }

    private static func lightningPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: width * 0.60, y: height))
        path.addLine(to: CGPoint(x: width * 0.17, y: height * 0.55))
        path.addLine(to: CGPoint(x: width * 0.47, y: height * 0.55))
        path.addLine(to: CGPoint(x: width * 0.31, y: 0))
        path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.64))
        path.addLine(to: CGPoint(x: width * 0.57, y: height * 0.64))
        path.closeSubpath()
        return path
    }
}

private final class PetAmbientParticleLayer: CALayer {
    private var configuredKind: PetAmbientEffectKind = .none
    private var configuredStretch = 0.0

    init(kind: PetAmbientEffectKind, stretch: Double) {
        super.init()
        actions = disabledLayerActions()
        bounds = CGRect(x: 0, y: 0, width: 64, height: 64)
        configure(kind: kind, stretch: stretch)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(
        kind: PetAmbientEffectKind,
        sample: PetAmbientParticleSample,
        unit: CGFloat,
        contentsScale: CGFloat
    ) {
        configure(kind: kind, stretch: sample.stretch)
        self.contentsScale = contentsScale
        position = CGPoint(
            x: (64 + sample.x) * unit,
                y: (64 - sample.y) * unit
        )
        opacity = Float(sample.opacity)

        let xScale = unit * sample.scale
        let yScale = kind == .storm ? xScale * sample.stretch : xScale
        setAffineTransform(
            CGAffineTransform(rotationAngle: -sample.rotationDegrees * .pi / 180)
                .scaledBy(x: xScale, y: yScale)
        )
    }

    private func configure(kind: PetAmbientEffectKind, stretch: Double) {
        guard configuredKind != kind || configuredStretch != stretch else { return }
        sublayers?.forEach { $0.removeFromSuperlayer() }

        switch kind {
        case .storm:
            addShape(
                rect: centeredRect(width: 2.6, height: 6.4),
                color: NSColor(calibratedRed: 0.10, green: 0.65, blue: 0.96, alpha: 1),
                shadowColor: NSColor(
                    calibratedRed: 0.08,
                    green: 0.52,
                    blue: 0.92,
                    alpha: 0.32
                ),
                shadowRadius: 0.7
            )
            addShape(
                    rect: centeredRect(width: 1.2, height: 1.8, x: -0.5, y: 2),
                color: NSColor(calibratedRed: 0.48, green: 0.86, blue: 1.0, alpha: 1)
            )
        case .wind:
            let width = 19 * stretch
            let leftEdge = -width / 2
            addShape(
                rect: centeredRect(width: width, height: 2.2),
                color: NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.0, alpha: 1),
                shadowColor: NSColor.white.withAlphaComponent(0.18),
                shadowRadius: 1
            )
            let middleWidth = 11 * stretch
            addShape(
                rect: centeredRect(
                    width: middleWidth,
                    height: 1.5,
                    x: leftEdge + middleWidth / 2 + 5,
                    y: -3.5
                ),
                color: NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.96, alpha: 0.78)
            )
            addShape(
                rect: centeredRect(
                    width: 3.2,
                    height: 1.1,
                    x: leftEdge + 3.2 / 2 + 2,
                    y: 2.4
                ),
                color: NSColor.white.withAlphaComponent(0.82)
            )
        case .snow:
            let path = CGMutablePath()
            let flakeBar = CGRect(x: -3.8, y: -0.625, width: 7.6, height: 1.25)
            for angle in [0.0, 45.0, 90.0, 135.0] {
                let transform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
                    .rotated(by: angle * .pi / 180)
                path.addPath(
                    CGPath(rect: flakeBar, transform: nil),
                    transform: transform
                )
            }
            let snowflake = CAShapeLayer()
            snowflake.actions = disabledLayerActions()
            snowflake.frame = bounds
            snowflake.path = path
            snowflake.fillColor = NSColor(
                calibratedRed: 0.90,
                green: 0.97,
                blue: 1.0,
                alpha: 1
            ).cgColor
            snowflake.shadowColor = NSColor(
                calibratedRed: 0.56,
                green: 0.84,
                blue: 1.0,
                alpha: 0.48
            ).cgColor
            snowflake.shadowOpacity = 1
            snowflake.shadowOffset = .zero
            snowflake.shadowRadius = 1.2
            addSublayer(snowflake)
            addShape(
                rect: centeredRect(width: 2.1, height: 2.1),
                color: .white
            )
        case .none:
            break
        }

        configuredKind = kind
        configuredStretch = stretch
    }

    private func addShape(
        rect: CGRect,
        color: NSColor,
        shadowColor: NSColor? = nil,
        shadowRadius: CGFloat = 0
    ) {
        let shape = CAShapeLayer()
        shape.actions = disabledLayerActions()
        shape.frame = bounds
        shape.path = CGPath(rect: rect, transform: nil)
        shape.fillColor = color.cgColor
        if let shadowColor {
            shape.shadowColor = shadowColor.cgColor
            shape.shadowOpacity = 1
            shape.shadowOffset = .zero
            shape.shadowRadius = shadowRadius
        }
        addSublayer(shape)
    }

    private func centeredRect(
        width: CGFloat,
        height: CGFloat,
        x: CGFloat = 0,
        y: CGFloat = 0
    ) -> CGRect {
        CGRect(
            x: bounds.midX + x - width / 2,
            y: bounds.midY + y - height / 2,
            width: width,
            height: height
        )
    }
}

private func disabledLayerActions() -> [String: CAAction] {
    [
        "bounds": NSNull(),
        "contents": NSNull(),
        "opacity": NSNull(),
        "path": NSNull(),
        "position": NSNull(),
        "shadowOpacity": NSNull(),
        "transform": NSNull(),
    ]
}
