import AppKit
import PetsCore
import SwiftUI

struct PetSprite: View {
    let petID: PetID
    let visualContext: PetVisualContext
    let pixelation: PetSpritePixelation

    var body: some View {
        Group {
            if let definition = PetCatalog.definition(for: PetCatalog.resolvedPetID(petID)) {
                switch definition.renderSource {
                case let .assetPack(artPack):
                    AssetPetSprite(
                        definition: definition,
                        artPack: artPack,
                        visualContext: visualContext
                    )
                }
            }
        }
        .pixelatedSpriteEffect(pixelation)
    }
}

@MainActor
private final class PetArtImageCache {
    static let shared = PetArtImageCache()

    private let images = NSCache<NSURL, NSImage>()

    func image(for frame: PetAnimationFrame) -> NSImage? {
        guard let url = PetArtResourceLocator.url(for: frame) else { return nil }
        if let cached = images.object(forKey: url as NSURL) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        images.setObject(image, forKey: url as NSURL)
        return image
    }
}

private struct AssetPetSprite: View {
    let definition: PetDefinition
    let artPack: PetArtPack
    let visualContext: PetVisualContext

    private var requestedState: PetVisualState {
        PetVisualStateResolver.requestedState(for: visualContext)
    }

    private var animation: PetAnimation {
        artPack.resolvedAnimation(for: requestedState)
    }

    private var usesTimeline: Bool {
        visualContext.animationSettings.isIdleMotionEnabled
            && (
                animation.frames.count > 1
                    || animation.motion != .none
                    || visualContext.reaction != nil
            )
    }

    var body: some View {
        Group {
            if usesTimeline {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                    renderedFrame(at: timeline.date)
                }
            } else {
                renderedFrame(at: Date(timeIntervalSinceReferenceDate: 0))
            }
        }
        .id(requestedState)
        .transition(.opacity)
        .animation(
            .easeInOut(duration: definition.presentation.transitionDuration),
            value: requestedState
        )
    }

    @ViewBuilder
    private func renderedFrame(at date: Date) -> some View {
        let rawElapsed = date.timeIntervalSinceReferenceDate
        let phasedElapsed = rawElapsed
            + animation.totalDuration * visualContext.animationPhaseOffset
        let isAmbientMotionEnabled = visualContext.animationSettings.isIdleMotionEnabled
            && visualContext.reaction == nil
        let playbackElapsed = isAmbientMotionEnabled ? phasedElapsed : 0
        let playback = animation.playbackSample(at: playbackElapsed)
        let primaryFrame = animation.frames[playback.primaryFrameIndex]
        let secondaryFrame = playback.secondaryFrameIndex.map { animation.frames[$0] }
        let primaryImage = PetArtImageCache.shared.image(for: primaryFrame)
        let secondaryImage = secondaryFrame.flatMap(PetArtImageCache.shared.image(for:))
        let motionElapsed = rawElapsed
            + animation.motion.cycleDuration * visualContext.animationPhaseOffset
        let motion = sampledMotion(
            at: motionElapsed,
            isAmbientMotionEnabled: isAmbientMotionEnabled
        )

        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 128

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(definition.presentation.shadowOpacity))
                    .frame(
                        width: definition.presentation.shadowWidth * unit,
                        height: definition.presentation.shadowHeight * unit
                    )
                    .scaleEffect(x: motion.shadowScale, y: 1)
                    .opacity(motion.shadowOpacityMultiplier)
                    .offset(y: 45 * unit)

                if let primaryImage {
                    blendedPetImage(
                        primary: primaryImage,
                        secondary: secondaryImage,
                        secondaryOpacity: playback.secondaryOpacity
                    )
                        .scaleEffect(definition.presentation.contentScale)
                        .offset(
                            x: definition.presentation.anchorX * unit,
                            y: definition.presentation.anchorY * unit
                        )
                        .modifier(PetMotionSampleModifier(sample: motion))
                        .modifier(
                            PetReactionVisualModifier(
                                reaction: visualContext.reaction,
                                elapsed: rawElapsed,
                                isMotionEnabled: visualContext.animationSettings.isIdleMotionEnabled
                            )
                        )
                } else {
                    missingArtPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func sampledMotion(
        at phasedElapsed: TimeInterval,
        isAmbientMotionEnabled: Bool
    ) -> PetMotionSample {
        animation.motion.sample(at: phasedElapsed, isEnabled: isAmbientMotionEnabled)
    }

    @ViewBuilder
    private func blendedPetImage(
        primary: NSImage,
        secondary: NSImage?,
        secondaryOpacity: Double
    ) -> some View {
        ZStack {
            petImage(primary)
            if let secondary {
                petImage(secondary)
                    .opacity(secondaryOpacity)
            }
        }
    }

    private func petImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    private var missingArtPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo.badge.exclamationmark")
            Text(definition.id.rawValue)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
    }
}

private struct PetMotionSampleModifier: ViewModifier {
    let sample: PetMotionSample

    func body(content: Content) -> some View {
        content
            .scaleEffect(sample.scale)
            .rotationEffect(.degrees(sample.rotationDegrees))
            .offset(x: sample.xOffset, y: sample.yOffset)
    }
}

private struct PetReactionVisualModifier: ViewModifier {
    let reaction: PetReaction?
    let elapsed: TimeInterval
    let isMotionEnabled: Bool

    private var phase: CGFloat {
        CGFloat(sin(elapsed * 2.8))
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch reaction {
        case .some(.completion):
            content
                .saturation(1.18)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.72, blue: 0.24),
                            Color(red: 1.0, green: 0.38, blue: 0.34),
                            Color(red: 0.76, green: 0.35, blue: 0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .opacity(0.72)
                    .mask(content)
                }
                .shadow(
                    color: Color(red: 1.0, green: 0.48, blue: 0.22).opacity(0.48),
                    radius: 9,
                    y: 1
                )
                .scaleEffect(isMotionEnabled ? 1 + (phase + 1) * 0.012 : 1)
                .offset(y: isMotionEnabled ? -2 - phase * 1.2 : 0)
        case .some(.error):
            content
                .saturation(0.28)
                .brightness(-0.18)
                .colorMultiply(Color(red: 0.55, green: 0.62, blue: 0.72))
                .shadow(color: Color.black.opacity(0.42), radius: 7, y: 3)
                .offset(y: isMotionEnabled ? 2 + abs(phase) * 0.8 : 0)
        case nil:
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func pixelatedSpriteEffect(_ pixelation: PetSpritePixelation) -> some View {
        if pixelation == .off {
            self
        } else {
            PixelatedSpriteRasterizer(pixelation: pixelation) {
                self
            }
        }
    }
}

private struct PixelatedSpriteRasterizer<Content: View>: NSViewRepresentable {
    let pixelation: PetSpritePixelation
    let content: Content

    init(pixelation: PetSpritePixelation, @ViewBuilder content: () -> Content) {
        self.pixelation = pixelation
        self.content = content()
    }

    func makeNSView(context: Context) -> PixelatedSpriteRasterView<Content> {
        PixelatedSpriteRasterView(rootView: content, pixelation: pixelation)
    }

    func updateNSView(_ nsView: PixelatedSpriteRasterView<Content>, context: Context) {
        nsView.update(rootView: content, pixelation: pixelation)
    }
}

@MainActor
private final class PixelatedSpriteRasterView<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private let imageLayer = CALayer()
    private var snapshotTask: Task<Void, Never>?
    private var pixelation: PetSpritePixelation

    init(rootView: Content, pixelation: PetSpritePixelation) {
        self.hostingView = NSHostingView(rootView: rootView)
        self.pixelation = pixelation
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        snapshotTask?.cancel()
    }

    override var isOpaque: Bool {
        false
    }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
        hostingView.frame = offscreenHostingFrame()
        renderSnapshotSoon()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopSnapshotLoop()
        } else {
            startSnapshotLoop()
            renderSnapshotSoon()
        }
    }

    func update(rootView: Content, pixelation: PetSpritePixelation) {
        hostingView.rootView = rootView
        self.pixelation = pixelation
        renderSnapshotSoon()
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true

        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .nearest
        imageLayer.minificationFilter = .nearest
        imageLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(imageLayer)

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        addSubview(hostingView)
    }

    private func startSnapshotLoop() {
        guard snapshotTask == nil else { return }
        snapshotTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.renderSnapshot()
                try? await Task.sleep(for: .milliseconds(83))
            }
        }
    }

    private func stopSnapshotLoop() {
        snapshotTask?.cancel()
        snapshotTask = nil
    }

    private func renderSnapshotSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.renderSnapshot()
        }
    }

    private func renderSnapshot() {
        guard bounds.width > 1, bounds.height > 1 else { return }

        hostingView.frame = offscreenHostingFrame()
        hostingView.layoutSubtreeIfNeeded()

        guard let highResolutionBitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return
        }
        highResolutionBitmap.size = hostingView.bounds.size
        hostingView.cacheDisplay(in: hostingView.bounds, to: highResolutionBitmap)

        guard let pixelatedImage = makePixelatedImage(from: highResolutionBitmap) else {
            return
        }
        imageLayer.contents = pixelatedImage
    }

    private func makePixelatedImage(from sourceBitmap: NSBitmapImageRep) -> CGImage? {
        let lowResolutionSize = NSSize(
            width: max(1, floor(bounds.width / CGFloat(pixelation.renderScale))),
            height: max(1, floor(bounds.height / CGFloat(pixelation.renderScale)))
        )
        guard let lowResolutionBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(lowResolutionSize.width),
            pixelsHigh: Int(lowResolutionSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        lowResolutionBitmap.size = lowResolutionSize

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: lowResolutionBitmap) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .none
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: lowResolutionSize).fill()
            sourceBitmap.draw(in: NSRect(origin: .zero, size: lowResolutionSize))
        }
        NSGraphicsContext.restoreGraphicsState()

        return lowResolutionBitmap.cgImage
    }

    private func offscreenHostingFrame() -> NSRect {
        NSRect(
            x: bounds.maxX + 16,
            y: 0,
            width: bounds.width,
            height: bounds.height
        )
    }
}
