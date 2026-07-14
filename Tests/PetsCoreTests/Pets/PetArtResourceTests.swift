import AppKit
import ImageIO
import Testing
@testable import PetsCore

@Suite
struct PetArtResourceTests {
    @Test
    func cumulusHasCompleteIdleLoop() throws {
        try assertCompleteIdleLoop(petID: .cuteCloud)
    }

    @Test
    func nimbusHasCompleteIdleLoop() throws {
        try assertCompleteIdleLoop(petID: .nimbusCloud)
    }

    @Test
    func cirrusHasCompleteIdleLoop() throws {
        try assertCompleteIdleLoop(petID: .cirrusCloud)
    }

    @Test
    func lenticularHasCompleteIdleLoop() throws {
        try assertCompleteIdleLoop(petID: .lenticularCloud)
    }

    @Test
    func snowHasCompleteIdleLoop() throws {
        try assertCompleteIdleLoop(petID: .snowCloud)
    }

    @Test
    func everyCloudHasExactlyEightIdleFrames() throws {
        for definition in PetCatalog.definitions {
            guard case let .assetPack(pack) = definition.renderSource else {
                Issue.record("Every cloud must use an asset pack")
                continue
            }
            #expect(pack.idle.frames.count == 8)
            #expect(pack.idle.frames.map(\.resourceName) == (0..<8).map {
                String(format: "frame-%03d", $0)
            })
        }
    }

    @Test
    func locatorFindsBundledFrameAndRejectsMissingFrame() {
        let existing = PetAnimationFrame(
            resourceName: "frame-000",
            resourceExtension: "png",
            subdirectory: "PetArt/cute-cloud/idle",
            duration: 1
        )
        let missing = PetAnimationFrame(
            resourceName: "missing",
            resourceExtension: "png",
            subdirectory: "PetArt/cute-cloud/idle",
            duration: 1
        )

        #expect(PetArtResourceLocator.url(for: existing) != nil)
        #expect(PetArtResourceLocator.url(for: missing) == nil)
    }

    @Test
    func lootChestArtworkIsBundledAndTransparent() throws {
        for chest in PetChestArtResource.allCases {
            let url = try #require(PetArtResourceLocator.url(for: chest))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let bitmap = NSBitmapImageRep(cgImage: image)

            #expect(image.width == image.height)
            #expect(image.width >= 1_000)
            #expect(image.alphaInfo != .none)
            let corners = [
                bitmap.colorAt(x: 0, y: 0),
                bitmap.colorAt(x: image.width - 1, y: 0),
                bitmap.colorAt(x: 0, y: image.height - 1),
                bitmap.colorAt(x: image.width - 1, y: image.height - 1),
            ]
            #expect(corners.allSatisfy { ($0?.alphaComponent ?? 1) == 0 })
        }
    }

    @Test
    func registeredAssetPacksUseValidProductionFrames() throws {
        for definition in PetCatalog.definitions {
            guard case let .assetPack(pack) = definition.renderSource else { continue }
            let animations = [
                pack.idle,
                pack.busy,
                pack.waiting,
                pack.excited,
                pack.sleeping,
                pack.completion,
                pack.error,
            ].compactMap { $0 }

            for animation in animations {
                for frame in animation.frames {
                    let url = try #require(PetArtResourceLocator.url(for: frame))
                    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
                    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

                    #expect(image.width == 512)
                    #expect(image.height == 512)
                    #expect(image.alphaInfo != .none)
                    #expect(image.alphaInfo != .noneSkipFirst)
                    #expect(image.alphaInfo != .noneSkipLast)

                    let bitmap = NSBitmapImageRep(cgImage: image)
                    let corners = [
                        bitmap.colorAt(x: 0, y: 0),
                        bitmap.colorAt(x: image.width - 1, y: 0),
                        bitmap.colorAt(x: 0, y: image.height - 1),
                        bitmap.colorAt(x: image.width - 1, y: image.height - 1)
                    ]
                    #expect(corners.allSatisfy { ($0?.alphaComponent ?? 1) == 0 })
                }
            }
        }
    }

    @Test
    func idleFramesStayAnchoredToCanonicalBounds() throws {
        for definition in PetCatalog.definitions {
            guard case let .assetPack(pack) = definition.renderSource else { continue }
            let images = try pack.idle.frames.map { frame -> CGImage in
                let url = try #require(PetArtResourceLocator.url(for: frame))
                let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
                return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            }
            let canonical = try #require(alphaBounds(in: images[0]))
            let sizeTolerance = definition.id == .cuteCloud || definition.id == .lenticularCloud
                ? 0.08
                : 0.12

            for image in images.dropFirst() {
                let bounds = try #require(alphaBounds(in: image))
                #expect(abs(bounds.midX - canonical.midX) <= 8)
                #expect(abs(bounds.midY - canonical.midY) <= 8)
                #expect(abs(bounds.width - canonical.width) / canonical.width <= sizeTolerance)
                #expect(abs(bounds.height - canonical.height) / canonical.height <= sizeTolerance)
            }
        }
    }

    @Test
    func alphaBoundsIgnoreDetachedSpecks() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 32,
            height: 32,
            bitsPerComponent: 8,
            bytesPerRow: 32 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 8, y: 9, width: 6, height: 5))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 4))

        let image = try #require(context.makeImage())
        #expect(alphaBounds(in: image) == CGRect(x: 8, y: 18, width: 6, height: 5))
    }

    @Test
    func alphaBoundsIncludeSubstantiveDetachedFeatures() throws {
        let context = try #require(CGContext(
            data: nil,
            width: 32,
            height: 32,
            bitsPerComponent: 8,
            bytesPerRow: 32 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 8, y: 9, width: 6, height: 5))
        context.fill(CGRect(x: 24, y: 12, width: 4, height: 4))

        let image = try #require(context.makeImage())
        #expect(alphaBounds(in: image) == CGRect(x: 8, y: 16, width: 20, height: 7))
    }

    @Test
    func lenticularEarlyHoverBandsMoveOppositelyAndPeakDeepens() throws {
        let definition = try #require(PetCatalog.definition(for: .lenticularCloud))
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Lenticular must use an asset pack")
            return
        }
        let images = try pack.idle.frames.prefix(3).map { frame -> CGImage in
            let url = try #require(PetArtResourceLocator.url(for: frame))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        }
        let canonical = try #require(lenticularBandSample(in: images[0]))
        let earlyHover = try #require(lenticularBandSample(in: images[1]))
        let peak = try #require(lenticularBandSample(in: images[2]))

        #expect(earlyHover.upperMidX <= canonical.upperMidX - 4)
        #expect(earlyHover.lowerMidX >= canonical.lowerMidX + 4)
        #expect(peak.upperMidX <= earlyHover.upperMidX - 0.25)
        #expect(peak.lowerMidX >= earlyHover.lowerMidX + 1)
        #expect(peak.bounds.midY < earlyHover.bounds.midY)
    }

    private func assertCompleteIdleLoop(petID: PetID) throws {
        let definition = try #require(PetCatalog.definition(for: petID))
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("\(definition.displayName) must use an asset pack")
            return
        }

        #expect(pack.idle.frames.map(\.resourceName) == (0..<8).map {
            String(format: "frame-%03d", $0)
        })
        #expect(pack.idle.frames.map(\.duration) == [2.00, 0.65, 0.55, 0.65, 1.45, 0.08, 0.10, 0.08])
        #expect(pack.idle.frames.map(\.blendDuration) == [0.22, 0.18, 0.20, 0.18, 0.12, 0.04, 0.04, 0.04])
    }

    private func alphaBounds(in image: CGImage) -> CGRect? {
        let pixels = substantiveAlphaPixels(in: image)
        guard let first = pixels.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for pixel in pixels.dropFirst() {
            minX = min(minX, pixel.x)
            maxX = max(maxX, pixel.x)
            minY = min(minY, pixel.y)
            maxY = max(maxY, pixel.y)
        }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    private func lenticularBandSample(
        in image: CGImage
    ) -> (upperMidX: CGFloat, lowerMidX: CGFloat, bounds: CGRect)? {
        let pixels = substantiveAlphaPixels(in: image)
        guard let bounds = alphaBounds(in: image) else { return nil }

        // Relative crops remain stable as the character rises and its silhouette breathes:
        // the top 40% isolates the cap assembly, while the bottom 28% isolates the base.
        let upperLimit = bounds.minY + bounds.height * 0.40
        let lowerLimit = bounds.maxY - bounds.height * 0.28
        let upper = pixels.filter { CGFloat($0.y) < upperLimit }
        let lower = pixels.filter { CGFloat($0.y) >= lowerLimit }
        guard !upper.isEmpty, !lower.isEmpty else { return nil }

        return (
            upperMidX: upper.reduce(CGFloat.zero) { $0 + CGFloat($1.x) } / CGFloat(upper.count),
            lowerMidX: lower.reduce(CGFloat.zero) { $0 + CGFloat($1.x) } / CGFloat(lower.count),
            bounds: bounds
        )
    }

    private func substantiveAlphaPixels(in image: CGImage) -> [(x: Int, y: Int)] {
        let bitmap = NSBitmapImageRep(cgImage: image)
        let width = image.width
        let height = image.height
        var occupied = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                occupied[y * width + x] = (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01
            }
        }

        var visited = [Bool](repeating: false, count: occupied.count)
        var substantivePixels: [(x: Int, y: Int)] = []

        // Ignore only tiny extraction noise while retaining detached sprite details such as
        // raindrops. Sixteen occupied pixels is above Lenticular's 8-pixel speck and far
        // below Nimbus's smallest legitimate detached weather component (223 pixels).
        let minimumSubstantiveComponentPixels = 16

        for start in occupied.indices where occupied[start] && !visited[start] {
            var queue = [start]
            var cursor = 0
            visited[start] = true

            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width
                let y = index / width

                for neighborY in max(0, y - 1)...min(height - 1, y + 1) {
                    for neighborX in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = neighborY * width + neighborX
                        if occupied[neighbor] && !visited[neighbor] {
                            visited[neighbor] = true
                            queue.append(neighbor)
                        }
                    }
                }
            }

            if queue.count >= minimumSubstantiveComponentPixels {
                substantivePixels.append(contentsOf: queue.map { ($0 % width, $0 / width) })
            }
        }

        return substantivePixels
    }
}
