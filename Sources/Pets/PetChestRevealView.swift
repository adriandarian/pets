import AppKit
import PetsCore
import SwiftUI

struct UnlockedPetSheet: View {
    @ObservedObject var store: PetStore
    let petID: PetID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealPhase = ChestRevealPhase.closed
    @State private var shakeOffset: CGFloat = 0
    @State private var shakeRotation = 0.0
    @State private var lidOpenAmount = 0.0
    @State private var petRevealAmount = 0.0

    private static let shakeSequence: [(offset: CGFloat, rotation: Double)] = [
        (-11, -4.5),
        (11, 4.5),
        (-9, -3.5),
        (9, 3.5),
        (-5, -2),
        (0, 0),
    ]

    var body: some View {
        ZStack {
            revealBackground

            VStack(spacing: 12) {
                VStack(spacing: 5) {
                    Image(systemName: revealPhase == .revealed ? "sparkles" : "shippingbox.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(rarityColor)
                        .contentTransition(.symbolEffect(.replace))

                    Text(revealPhase.title(for: rarity))
                        .font(.title2.bold())
                        .contentTransition(.numericText())
                }

                revealStage

                ZStack {
                    if revealPhase == .revealed {
                        petDetails
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Label(revealPhase.status, systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .frame(height: 58)

                Button("Done") {
                    store.dismissUnlockedPet()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .opacity(revealPhase == .revealed ? 1 : 0)
                .allowsHitTesting(revealPhase == .revealed)
                .accessibilityHidden(revealPhase != .revealed)
            }
            .padding(30)
        }
        .frame(width: 470, height: 520)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(revealPhase != .revealed)
        .task(id: petID) {
            await runRevealSequence()
        }
    }

    private var revealStage: some View {
        ZStack {
            Circle()
                .fill(rarityColor.opacity(0.28))
                .frame(width: 190, height: 190)
                .blur(radius: 28)
                .scaleEffect(lidOpenAmount == 0 ? 0.45 : 1.15)
                .opacity(lidOpenAmount == 0 ? 0 : 1)

            if revealPhase == .revealed {
                ChestSparkleField(color: rarityColor)
                    .scaleEffect(petRevealAmount)
                    .opacity(petRevealAmount)
                    .transition(.opacity)
            }

            ChestOpeningArtwork(rarity: rarity, lidOpenAmount: lidOpenAmount)
                .frame(width: 245, height: 245)
                .rotationEffect(.degrees(shakeRotation), anchor: .bottom)
                .offset(
                    x: shakeOffset,
                    y: revealPhase == .revealed ? -6 : 8
                )
                .scaleEffect(revealPhase == .revealed ? 1.16 : 1)
                .opacity(revealPhase == .revealed ? 0 : 1)

            if revealPhase == .revealed {
                PetSprite(
                    petID: petID,
                    visualContext: PetVisualContext(
                        status: .idle,
                        hasActiveSessions: true,
                        isHovered: false,
                        animationSettings: .default
                    ),
                    pixelation: .off
                )
                .frame(width: 158, height: 158)
                .scaleEffect(0.55 + (petRevealAmount * 0.45))
                .offset(y: 12 - (petRevealAmount * 24))
                .opacity(petRevealAmount)
                .transition(.scale(scale: 0.55).combined(with: .opacity))
                .accessibilityLabel(PetCatalog.displayName(for: petID))
            }
        }
        .frame(height: 280)
    }

    private var petDetails: some View {
        VStack(spacing: 4) {
            Text(PetCatalog.displayName(for: petID))
                .font(.title3.weight(.semibold))
            Text(
                "\(rarity.displayName) · "
                    + (PetCatalog.category(for: petID)?.displayName ?? "Pet")
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var revealBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            RadialGradient(
                colors: [rarityColor.opacity(0.16), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 310
            )
        }
        .ignoresSafeArea()
    }

    private var rarity: PetRarity {
        PetCatalog.rarity(for: petID)
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: .mint
        case .rare: .blue
        case .legendary: .orange
        }
    }

    @MainActor
    private func runRevealSequence() async {
        revealPhase = .closed
        shakeOffset = 0
        shakeRotation = 0
        lidOpenAmount = 0
        petRevealAmount = 0

        do {
            try await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 260))

            if !reduceMotion {
                revealPhase = .shaking
                for shake in Self.shakeSequence {
                    withAnimation(.easeInOut(duration: 0.085)) {
                        shakeOffset = shake.offset
                        shakeRotation = shake.rotation
                    }
                    try await Task.sleep(for: .milliseconds(90))
                }
            }

            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.7)) {
                revealPhase = .opening
                lidOpenAmount = 1
                shakeOffset = 0
                shakeRotation = 0
            }
            try await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 900))

            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.67)) {
                revealPhase = .revealed
                petRevealAmount = 1
            }
        } catch is CancellationError {
            // The sheet or its parent window was dismissed before the reveal completed.
        } catch {
            // No other error is expected from the animation clock.
        }
    }
}

private enum ChestRevealPhase: Equatable {
    case closed
    case shaking
    case opening
    case revealed

    func title(for rarity: PetRarity) -> String {
        switch self {
        case .closed:
            "\(rarity.displayName) Chest"
        case .shaking:
            "Something's Inside…"
        case .opening:
            "Opening…"
        case .revealed:
            "New Pet Unlocked"
        }
    }

    var status: String {
        switch self {
        case .closed:
            "Get ready…"
        case .shaking:
            "The chest is waking up"
        case .opening:
            "Unlocking your new companion"
        case .revealed:
            ""
        }
    }
}

private struct ChestOpeningArtwork: View {
    let rarity: PetRarity
    let lidOpenAmount: Double

    var body: some View {
        ZStack {
            PetChestArtwork(rarity: rarity)
                .scaleEffect(1 - (lidOpenAmount * 0.06))
                .opacity(1 - lidOpenAmount)

            PetOpenChestArtwork(rarity: rarity)
                .scaleEffect(0.88 + (lidOpenAmount * 0.12))
                .opacity(lidOpenAmount)

            ChestSparkleField(color: rarityColor)
                .scaleEffect(0.35 + (lidOpenAmount * 0.65))
                .opacity(lidOpenAmount)

            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow, radius: 9)
                .scaleEffect(0.3 + (lidOpenAmount * 0.9))
                .opacity(lidOpenAmount)
                .offset(y: -5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lidOpenAmount == 0 ? "Closed pet chest" : "Pet chest with its lid open")
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: .mint
        case .rare: .blue
        case .legendary: .orange
        }
    }
}

private struct PetOpenChestArtwork: View {
    let rarity: PetRarity

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .blendMode(.screen)
            }
        }
        .accessibilityHidden(true)
    }

    private var image: NSImage? {
        guard let url = PetArtResourceLocator.url(forOpenChest: resource) else { return nil }
        return NSImage(contentsOf: url)
    }

    private var resource: PetOpenChestArtResource {
        switch rarity {
        case .common: .common
        case .rare: .rare
        case .legendary: .legendary
        }
    }
}

private struct ChestSparkleField: View {
    let color: Color

    private let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-92, -70, 14),
        (90, -58, 11),
        (-112, 12, 9),
        (108, 26, 14),
        (-76, 72, 10),
        (82, 78, 8),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(sparkles.enumerated()), id: \.offset) { _, sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: sparkle.x, y: sparkle.y)
            }
        }
        .accessibilityHidden(true)
    }
}
