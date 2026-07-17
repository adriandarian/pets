import AppKit
import ImageIO
import Testing
@testable import PetsCore

@Suite
struct NimbusCloudArtTests {
    @Test
    func sourceFramesContainNoBakedRainOrLightning() throws {
        let definition = try #require(PetCatalog.definition(for: .nimbusCloud))
        guard case let .assetPack(pack) = definition.renderSource else {
            Issue.record("Nimbus must use an asset pack")
            return
        }

        for frame in pack.idle.frames {
            let url = try #require(PetArtResourceLocator.url(for: frame))
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let bitmap = NSBitmapImageRep(cgImage: image)
            let data = try #require(bitmap.bitmapData)
            var weatherPixelCount = 0

            for y in 0..<bitmap.pixelsHigh {
                let normalizedY = Double(y) / Double(bitmap.pixelsHigh)
                for x in 0..<bitmap.pixelsWide {
                    let byteIndex = y * bitmap.bytesPerRow + x * 4
                    guard data[byteIndex + 3] > 0 else { continue }

                    let red = Double(data[byteIndex]) / 255
                    let green = Double(data[byteIndex + 1]) / 255
                    let blue = Double(data[byteIndex + 2]) / 255
                    let isRain = normalizedY > 250.0 / 512.0
                        && blue - red > 0.14
                        && green - red > 0.08
                        && blue > 0.40
                    let isLightning = normalizedY > 300.0 / 512.0
                        && red - blue > 0.16
                        && green - blue > 0.08
                        && red > 0.55
                        && green > 0.32
                        && blue < 0.65
                    weatherPixelCount += isRain || isLightning ? 1 : 0
                }
            }

            #expect(
                weatherPixelCount == 0,
                "\(frame.resourceName) still contains \(weatherPixelCount) weather pixels"
            )
        }
    }
}
