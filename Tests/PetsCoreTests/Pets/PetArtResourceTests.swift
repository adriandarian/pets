import AppKit
import ImageIO
import Testing
@testable import PetsCore

@Suite
struct PetArtResourceTests {
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
    func registeredAssetPacksUseValidProductionFrames() throws {
        for definition in PetCatalog.definitions {
            guard case let .assetPack(pack) = definition.renderSource else { continue }
            let animations = [pack.idle, pack.busy, pack.waiting, pack.excited, pack.sleeping].compactMap { $0 }

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
}
