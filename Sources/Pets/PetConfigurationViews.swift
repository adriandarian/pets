import PetsCore
import SwiftUI

struct PetConfigurationPane: View {
    @ObservedObject var store: PetStore
    let respawnPet: (PetInstance.ID) -> Void
    @Binding var isPetPickerPresented: Bool
    @State private var petPendingDeletionID: PetInstance.ID?

    var body: some View {
        ZStack {
            NavigationSplitView {
                PetSidebar(store: store, respawnPet: respawnPet)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 208, max: 250)
            } detail: {
                Group {
                    if let selectedPet {
                        PetDetailPane(
                            store: store,
                            pet: selectedPet,
                            respawnPet: { respawnPet(selectedPet.id) },
                            changePet: { isPetPickerPresented = true },
                            deletePet: { petPendingDeletionID = selectedPet.id }
                        )
                    } else {
                        EmptyPetCollectionView { store.addPet() }
                    }
                }
            }

            if isPetPickerPresented {
                PetPickerOverlay(store: store, isPresented: $isPetPickerPresented)
            }
        }
        .confirmationDialog(
            "Delete \(petPendingDeletion?.name ?? "Pet")?",
            isPresented: isDeleteConfirmationPresented,
            presenting: petPendingDeletion
        ) { pet in
            Button("Delete Pet", role: .destructive) {
                store.removePet(pet.id)
                petPendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { pet in
            Text("This removes \(pet.name) from your collection.")
        }
    }

    private var selectedPet: PetInstance? {
        store.selectedPetInstance
    }

    private var petPendingDeletion: PetInstance? {
        guard let petPendingDeletionID else { return nil }
        return store.petInstance(for: petPendingDeletionID)
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { petPendingDeletionID != nil },
            set: { isPresented in
                if !isPresented { petPendingDeletionID = nil }
            }
        )
    }
}

struct EmptyPetCollectionView: View {
    let addPet: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Pets")
                .font(.title2.bold())
            Text("Add a pet when you want one on your desktop.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: addPet) {
                Label("Add Pet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
