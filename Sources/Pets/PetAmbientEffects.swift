import PetsCore
import SwiftUI

enum PetAmbientEffectLayer {
    case background
    case foreground
}

struct PetAmbientEffectView: View {
    let kind: PetAmbientEffectKind
    let sample: PetAmbientEffectSample
    let unit: CGFloat
    let layer: PetAmbientEffectLayer

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, _ in
            switch (kind, layer) {
            case (.storm, .foreground):
                drawStorm(in: &context)
            case (.wind, .background):
                drawWind(in: &context)
            case (.snow, .foreground):
                drawSnow(in: &context)
            case (.lifeSparks, .foreground):
                drawLifeSparks(in: &context)
            default:
                break
            }
        }
        .frame(width: 128 * unit, height: 128 * unit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStorm(in context: inout GraphicsContext) {
        for particle in sample.particles {
            context.drawLayer { particleContext in
                particleContext.opacity = particle.opacity
                particleContext.translateBy(
                    x: (64 + particle.x) * unit,
                    y: (64 + particle.y) * unit
                )
                particleContext.rotate(by: .degrees(particle.rotationDegrees))
                particleContext.scaleBy(
                    x: particle.scale,
                    y: particle.scale * particle.stretch
                )
                particleContext.addFilter(
                    .shadow(
                        color: Color(red: 0.08, green: 0.52, blue: 0.92).opacity(0.32),
                        radius: 0.7 * unit * particle.scale
                    )
                )

                particleContext.fill(
                    centeredRectangle(width: 2.6 * unit, height: 6.4 * unit),
                    with: .color(Color(red: 0.10, green: 0.65, blue: 0.96))
                )
                particleContext.fill(
                    centeredRectangle(
                        width: 1.2 * unit,
                        height: 1.8 * unit,
                        x: -0.5 * unit,
                        y: -2 * unit
                    ),
                    with: .color(Color(red: 0.48, green: 0.86, blue: 1.0))
                )
            }
        }

        let lightningScale = 0.94 + sample.lightningIntensity * 0.10
        context.drawLayer { lightningContext in
            lightningContext.opacity = sample.lightningIntensity
            lightningContext.translateBy(x: 64 * unit, y: 97.5 * unit)
            lightningContext.scaleBy(x: lightningScale, y: lightningScale)
            lightningContext.addFilter(
                .shadow(
                    color: Color(red: 1.0, green: 0.68, blue: 0.12)
                        .opacity(sample.lightningIntensity * 0.88),
                    radius: 4 * unit * lightningScale
                )
            )
            lightningContext.fill(
                lightningPath(width: 20 * unit, height: 50 * unit),
                with: .color(Color(red: 1.0, green: 0.77, blue: 0.20))
            )
        }
    }

    private func drawWind(in context: inout GraphicsContext) {
        for particle in sample.particles {
            let width = 19 * CGFloat(particle.stretch) * unit
            let leftEdge = -width / 2

            context.drawLayer { particleContext in
                particleContext.opacity = particle.opacity
                particleContext.translateBy(
                    x: (64 + particle.x) * unit,
                    y: (64 + particle.y) * unit
                )
                particleContext.scaleBy(x: particle.scale, y: particle.scale)
                particleContext.addFilter(
                    .shadow(
                        color: Color.white.opacity(0.18),
                        radius: unit * particle.scale
                    )
                )

                particleContext.fill(
                    centeredRectangle(width: width, height: 2.2 * unit),
                    with: .color(Color(red: 0.90, green: 0.95, blue: 1.0))
                )

                let middleWidth = 11 * CGFloat(particle.stretch) * unit
                particleContext.fill(
                    centeredRectangle(
                        width: middleWidth,
                        height: 1.5 * unit,
                        x: leftEdge + middleWidth / 2 + 5 * unit,
                        y: 3.5 * unit
                    ),
                    with: .color(Color(red: 0.72, green: 0.84, blue: 0.96).opacity(0.78))
                )

                let highlightWidth = 3.2 * unit
                particleContext.fill(
                    centeredRectangle(
                        width: highlightWidth,
                        height: 1.1 * unit,
                        x: leftEdge + highlightWidth / 2 + 2 * unit,
                        y: -2.4 * unit
                    ),
                    with: .color(Color.white.opacity(0.82))
                )
            }
        }
    }

    private func drawSnow(in context: inout GraphicsContext) {
        for particle in sample.particles {
            context.drawLayer { particleContext in
                particleContext.opacity = particle.opacity
                particleContext.translateBy(
                    x: (64 + particle.x) * unit,
                    y: (64 + particle.y) * unit
                )
                particleContext.rotate(by: .degrees(particle.rotationDegrees))
                particleContext.scaleBy(x: particle.scale, y: particle.scale)
                particleContext.addFilter(
                    .shadow(
                        color: Color(red: 0.56, green: 0.84, blue: 1.0).opacity(0.48),
                        radius: 1.2 * unit * particle.scale
                    )
                )

                for rotation in [0.0, 45.0, 90.0, 135.0] {
                    particleContext.drawLayer { barContext in
                        barContext.rotate(by: .degrees(rotation))
                        barContext.fill(
                            centeredRectangle(width: 7.6 * unit, height: 1.25 * unit),
                            with: .color(Color(red: 0.90, green: 0.97, blue: 1.0))
                        )
                    }
                }

                particleContext.fill(
                    centeredRectangle(width: 2.1 * unit, height: 2.1 * unit),
                    with: .color(.white)
                )
            }
        }
    }

    private func drawLifeSparks(in context: inout GraphicsContext) {
        for particle in sample.particles {
            context.drawLayer { particleContext in
                particleContext.opacity = particle.opacity
                particleContext.translateBy(
                    x: (64 + particle.x) * unit,
                    y: (64 + particle.y) * unit
                )
                particleContext.rotate(by: .degrees(particle.rotationDegrees))
                particleContext.scaleBy(x: particle.scale, y: particle.scale)
                particleContext.addFilter(
                    .shadow(
                        color: Color(red: 1.0, green: 0.63, blue: 0.16).opacity(0.34),
                        radius: 1.1 * unit * particle.scale
                    )
                )
                particleContext.fill(
                    centeredRectangle(width: 2.8 * unit, height: 2.8 * unit),
                    with: .color(Color(red: 1.0, green: 0.78, blue: 0.30))
                )
                particleContext.fill(
                    centeredRectangle(width: 1.2 * unit, height: 1.2 * unit),
                    with: .color(Color(red: 1.0, green: 0.95, blue: 0.67))
                )
            }
        }
    }

    private func centeredRectangle(
        width: CGFloat,
        height: CGFloat,
        x: CGFloat = 0,
        y: CGFloat = 0
    ) -> Path {
        Path(
            CGRect(
                x: x - width / 2,
                y: y - height / 2,
                width: width,
                height: height
            )
        )
    }

    private func lightningPath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: width * 0.10, y: -height * 0.50))
        path.addLine(to: CGPoint(x: -width * 0.33, y: -height * 0.05))
        path.addLine(to: CGPoint(x: -width * 0.03, y: -height * 0.05))
        path.addLine(to: CGPoint(x: -width * 0.19, y: height * 0.50))
        path.addLine(to: CGPoint(x: width * 0.38, y: -height * 0.14))
        path.addLine(to: CGPoint(x: width * 0.07, y: -height * 0.14))
        path.closeSubpath()
        return path
    }
}
