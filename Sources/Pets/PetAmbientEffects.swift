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
        ZStack {
            switch (kind, layer) {
            case (.storm, .foreground):
                storm
            case (.wind, .background):
                wind
            case (.snow, .foreground):
                snow
            default:
                EmptyView()
            }
        }
        .frame(width: 128 * unit, height: 128 * unit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var storm: some View {
        ZStack {
            ForEach(sample.particles) { particle in
                VoxelRaindrop(unit: unit)
                    .scaleEffect(
                        x: particle.scale,
                        y: particle.scale * particle.stretch
                    )
                    .rotationEffect(.degrees(particle.rotationDegrees))
                    .opacity(particle.opacity)
                    .position(
                        x: (64 + particle.x) * unit,
                        y: (64 + particle.y) * unit
                    )
            }

            VoxelLightningBolt()
                .fill(Color(red: 1.0, green: 0.77, blue: 0.20))
                .frame(width: 13 * unit, height: 29 * unit)
                .shadow(
                    color: Color(red: 1.0, green: 0.68, blue: 0.12)
                        .opacity(sample.lightningIntensity * 0.88),
                    radius: 4 * unit
                )
                .scaleEffect(0.94 + sample.lightningIntensity * 0.10)
                .opacity(sample.lightningIntensity)
                .position(x: 64 * unit, y: 87 * unit)
        }
    }

    private var wind: some View {
        ZStack {
            ForEach(sample.particles) { particle in
                VoxelWindRibbon(unit: unit, stretch: particle.stretch)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(
                        x: (64 + particle.x) * unit,
                        y: (64 + particle.y) * unit
                    )
            }
        }
    }

    private var snow: some View {
        ZStack {
            ForEach(sample.particles) { particle in
                VoxelSnowflake(unit: unit)
                    .scaleEffect(particle.scale)
                    .rotationEffect(.degrees(particle.rotationDegrees))
                    .opacity(particle.opacity)
                    .position(
                        x: (64 + particle.x) * unit,
                        y: (64 + particle.y) * unit
                    )
            }
        }
    }
}

private struct VoxelRaindrop: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.10, green: 0.65, blue: 0.96))
                .frame(width: 2.6 * unit, height: 6.4 * unit)

            Rectangle()
                .fill(Color(red: 0.48, green: 0.86, blue: 1.0))
                .frame(width: 1.2 * unit, height: 1.8 * unit)
                .offset(x: -0.5 * unit, y: -2.0 * unit)
        }
        .shadow(
            color: Color(red: 0.08, green: 0.52, blue: 0.92).opacity(0.32),
            radius: 0.7 * unit
        )
    }
}

private struct VoxelLightningBolt: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.60, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.17, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.width * 0.47, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.width * 0.31, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.36))
        path.addLine(to: CGPoint(x: rect.width * 0.57, y: rect.height * 0.36))
        path.closeSubpath()
        return path
    }
}

private struct VoxelWindRibbon: View {
    let unit: CGFloat
    let stretch: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(red: 0.90, green: 0.95, blue: 1.0))
                .frame(width: 19 * CGFloat(stretch) * unit, height: 2.2 * unit)

            Rectangle()
                .fill(Color(red: 0.72, green: 0.84, blue: 0.96).opacity(0.78))
                .frame(width: 11 * CGFloat(stretch) * unit, height: 1.5 * unit)
                .offset(x: 5 * unit, y: 3.5 * unit)

            Rectangle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 3.2 * unit, height: 1.1 * unit)
                .offset(x: 2 * unit, y: -2.4 * unit)
        }
        .frame(
            width: 19 * CGFloat(stretch) * unit,
            height: 8 * unit,
            alignment: .leading
        )
        .shadow(color: Color.white.opacity(0.18), radius: unit)
    }
}

private struct VoxelSnowflake: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            flakeBar
            flakeBar.rotationEffect(.degrees(45))
            flakeBar.rotationEffect(.degrees(90))
            flakeBar.rotationEffect(.degrees(135))

            Rectangle()
                .fill(Color.white)
                .frame(width: 2.1 * unit, height: 2.1 * unit)
        }
        .frame(width: 8 * unit, height: 8 * unit)
        .shadow(
            color: Color(red: 0.56, green: 0.84, blue: 1.0).opacity(0.48),
            radius: 1.2 * unit
        )
    }

    private var flakeBar: some View {
        Rectangle()
            .fill(Color(red: 0.90, green: 0.97, blue: 1.0))
            .frame(width: 7.6 * unit, height: 1.25 * unit)
    }
}
