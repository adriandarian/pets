import PetsCore
import SwiftUI

enum PetSettingsDestination: Hashable, CaseIterable {
    case pets
    case chests
    case collection

    var title: String {
        switch self {
        case .pets: "Pets"
        case .chests: "Chests"
        case .collection: "Collection"
        }
    }

    var systemImage: String {
        switch self {
        case .pets: "pawprint"
        case .chests: "shippingbox"
        case .collection: "book.closed"
        }
    }
}

struct PetSettingsView: View {
    @ObservedObject var store: PetStore
    @ObservedObject var updateController: PetUpdateController
    let respawnPet: (PetInstance.ID) -> Void
    @State private var selectedDestination = PetSettingsDestination.pets
    @State private var isPetPickerPresented = false

    var body: some View {
        Group {
            switch selectedDestination {
            case .pets:
                PetConfigurationPane(
                    store: store,
                    respawnPet: respawnPet,
                    isPetPickerPresented: $isPetPickerPresented
                )
            case .chests:
                PetChestView(store: store)
            case .collection:
                PetCollectionView(store: store)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let release = updateController.availableRelease {
                PetUpdateBanner(
                    release: release,
                    openRelease: updateController.openAvailableRelease
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetSettingsDestinationBar(
                    selection: $selectedDestination,
                    isDisabled: isPetPickerPresented
                )
            }
        }
    }
}

private struct PetSettingsDestinationBar: View {
    @Binding var selection: PetSettingsDestination
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 18) {
            ForEach(PetSettingsDestination.allCases, id: \.self) { destination in
                Button {
                    selection = destination
                } label: {
                    VStack(spacing: 7) {
                        Label(destination.title, systemImage: destination.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(selection == destination ? Color.primary : Color.secondary)

                        Capsule()
                            .fill(selection == destination ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityLabel(destination.title)
                .accessibilityAddTraits(selection == destination ? .isSelected : [])
            }
        }
        .padding(.top, 6)
    }
}

private struct PetUpdateBanner: View {
    let release: PetsRelease
    let openRelease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pets \(release.displayVersion) is available")
                    .font(.headline)
                Text("Download it from GitHub and replace the app. Your pets and preferences will stay in place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button("View on GitHub", action: openRelease)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.10))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
