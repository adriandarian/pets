import AppKit
import PetsCore
import SwiftUI

private enum PetDetailSection: Hashable, CaseIterable {
    case details
    case tracking
    case lookAndMotion

    var title: String {
        switch self {
        case .details: "Details"
        case .tracking: "Tracking"
        case .lookAndMotion: "Look & Motion"
        }
    }

    var systemImage: String {
        switch self {
        case .details: "info.circle"
        case .tracking: "dot.radiowaves.left.and.right"
        case .lookAndMotion: "wand.and.stars"
        }
    }
}

struct PetDetailPane: View {
    @ObservedObject var store: PetStore
    let pet: PetInstance
    let respawnPet: () -> Void
    let changePet: () -> Void
    let deletePet: () -> Void
    @State private var selectedSection = PetDetailSection.details

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 30)
                .padding(.vertical, 16)

            Divider()

            HStack(alignment: .top, spacing: 28) {
                PetPreview(
                    pet: pet,
                    dominantStatus: store.dominantStatus(for: pet.id),
                    changePet: changePet
                )
                .frame(width: 260)

                VStack(alignment: .leading, spacing: 20) {
                    PetDetailSectionNavigation(selection: $selectedSection)

                    Divider()

                    Group {
                        switch selectedSection {
                        case .details:
                            PetDetailsSection(store: store)
                        case .tracking:
                            PetTrackingSection(store: store, pet: pet)
                        case .lookAndMotion:
                            PetBehaviorSection(store: store)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
            }
            .padding(.leading, 18)
            .padding(.trailing, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: pet.id) { _, _ in
            selectedSection = .details
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            PetSprite(
                petID: pet.petID,
                visualContext: PetVisualContext(
                    status: .idle,
                    hasActiveSessions: true,
                    isHovered: false,
                    animationSettings: pet.animationSettings
                ),
                pixelation: pet.pixelation
            )
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.title2.weight(.semibold))
                Text("\(petFamilyName) · \(pet.isVisible ? "Visible" : "Hidden") · \(store.trackingSummary(for: pet.id))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            Menu {
                Button("Respawn") { respawnPet() }
                Button(pet.isVisible ? "Hide" : "Show") {
                    store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
                }
                Divider()
                Button("Duplicate") { store.duplicatePet(pet.id) }
                Button("Delete", role: .destructive) { deletePet() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More pet actions")
            .accessibilityLabel("More pet actions")
        }
    }

    private var petFamilyName: String {
        PetCatalog.category(for: pet.petID)?.displayName ?? "Custom Pet"
    }
}

private struct PetDetailSectionNavigation: View {
    private static let titleVisibilityThreshold: CGFloat = 540
    private static let controlHeight: CGFloat = 36

    @Binding var selection: PetDetailSection

    var body: some View {
        ViewThatFits(in: .horizontal) {
            navigation(showsTitles: true)
                .frame(minWidth: Self.titleVisibilityThreshold)
            navigation(showsTitles: false)
        }
        .frame(height: Self.controlHeight)
    }

    private func navigation(showsTitles: Bool) -> some View {
        HStack(spacing: showsTitles ? 20 : 8) {
            ForEach(PetDetailSection.allCases, id: \.self) { section in
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 5) {
                        if showsTitles {
                            Label(section.title, systemImage: section.systemImage)
                                .lineLimit(1)
                                .fixedSize()
                        } else {
                            Image(systemName: section.systemImage)
                                .font(.title2)
                        }

                        Capsule()
                            .fill(selection == section ? Color.accentColor : Color.clear)
                            .frame(width: showsTitles ? 72 : 30, height: 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.controlHeight)
                    .foregroundStyle(selection == section ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: Self.controlHeight)
                .contentShape(Rectangle())
                .focusable()
                .focusEffectDisabled()
                .onKeyPress(.space) {
                    selection = section
                    return .handled
                }
                .onKeyPress(.return) {
                    selection = section
                    return .handled
                }
                .help(section.title)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
    }
}

private struct PetPreview: View {
    let pet: PetInstance
    let dominantStatus: HarnessSessionStatus
    let changePet: () -> Void
    @State private var isExpandedPreviewPresented = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            SpritePreviewGridBackground()
            PetSprite(
                petID: pet.petID,
                visualContext: PetVisualContext(
                    status: dominantStatus,
                    hasActiveSessions: dominantStatus != .unknown,
                    isHovered: false,
                    animationSettings: pet.animationSettings
                ),
                pixelation: pet.pixelation
            )
            .frame(width: 190, height: 190)
        }
        .frame(maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: changePet) {
                ZStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.medium))
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Change Pet")
            .accessibilityLabel("Change Pet")
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                isExpandedPreviewPresented = true
            } label: {
                Image(systemName: "arrow.down.left.and.arrow.up.right")
                    .font(.title3.weight(.medium))
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Expand preview")
            .accessibilityLabel("Expand preview")
            .padding(12)
        }
        .sheet(isPresented: $isExpandedPreviewPresented) {
            ExpandedPetPreview(pet: pet, dominantStatus: dominantStatus)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(pet.name) preview")
    }
}

private struct ExpandedPetPreview: View {
    let pet: PetInstance
    let dominantStatus: HarnessSessionStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            SpritePreviewGridBackground()
            PetSprite(
                petID: pet.petID,
                visualContext: PetVisualContext(
                    status: dominantStatus,
                    hasActiveSessions: dominantStatus != .unknown,
                    isHovered: false,
                    animationSettings: pet.animationSettings
                ),
                pixelation: pet.pixelation
            )
            .frame(width: 380, height: 380)
        }
        .frame(width: 560, height: 520)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.up.right.and.arrow.down.left")
                    .font(.title3.weight(.medium))
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close expanded preview (Esc)")
            .accessibilityLabel("Close expanded preview")
            .keyboardShortcut(.cancelAction)
            .padding(14)
        }
        .padding(20)
        .background {
            PetWindowOutsideClickMonitor { dismiss() }
        }
        .onExitCommand { dismiss() }
    }
}

private struct SpritePreviewGridBackground: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 18
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(
                path,
                with: .color(Color(nsColor: .separatorColor).opacity(0.45)),
                lineWidth: 1
            )
        }
        .padding(16)
        .allowsHitTesting(false)
    }
}

private struct PetDetailsSection: View {
    @ObservedObject var store: PetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsRow("Name") {
                TextField("", text: nameBinding)
                    .accessibilityLabel("Name")
            }

            Divider()

            settingsRow("Style") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(PetSpritePixelation.allCases, id: \.self) { pixelation in
                            Button {
                                store.updateSelectedPetPixelation(pixelation)
                            } label: {
                                VStack(spacing: 7) {
                                    Text(pixelation.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .fixedSize()
                                    Capsule()
                                        .fill(selectedPet.pixelation == pixelation ? Color.accentColor : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedPet.pixelation == pixelation ? Color.accentColor : Color.secondary)
                            .disabled(pixelation > PetCatalog.maximumPixelation(for: selectedPet.petID))
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Session preview")
                    Text("Lines shown in each session bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 3) {
                        Slider(
                            value: contextLineCountSliderBinding,
                            in: contextLineCountSliderRange,
                            step: 1
                        )
                        .accessibilityLabel("Session preview lines")
                        .accessibilityValue(sessionPreviewLabel)

                        HStack {
                            ForEach(PetSessionContextLineCount.supportedRange, id: \.self) { value in
                                Text("\(value)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                if value != PetSessionContextLineCount.supportedRange.upperBound {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Text(sessionPreviewLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 18) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    private var selectedPet: PetInstance {
        store.selectedPetInstance ?? PetInstance.defaultInstance()
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { store.selectedPetInstance?.name ?? "" },
            set: { store.updateSelectedPetName($0) }
        )
    }

    private var contextLineCountSliderBinding: Binding<Double> {
        Binding(
            get: { Double(selectedPet.sessionContextLineCount) },
            set: { store.updateSelectedPetContextLineCount(Int($0.rounded())) }
        )
    }

    private var contextLineCountSliderRange: ClosedRange<Double> {
        let lowerBound = Double(PetSessionContextLineCount.supportedRange.lowerBound)
        let upperBound = Double(PetSessionContextLineCount.supportedRange.upperBound)
        return lowerBound...upperBound
    }

    private var sessionPreviewLabel: String {
        let count = selectedPet.sessionContextLineCount
        return "\(count) \(count == 1 ? "line" : "lines")"
    }
}
