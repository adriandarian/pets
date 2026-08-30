import AppKit
import PetsCore
import SwiftUI

struct PetSidebar: View {
    @ObservedObject var store: PetStore
    let respawnPet: (PetInstance.ID) -> Void
    @State private var petBeingRenamedID: PetInstance.ID?
    @State private var renameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectedPetBinding) {
                Section("My Pets") {
                    ForEach(store.petInstances) { pet in
                        PetSidebarRow(
                            pet: pet,
                            isRenaming: petBeingRenamedID == pet.id,
                            renameDraft: $renameDraft,
                            commitRename: { commitRename(pet.id) },
                            cancelRename: { cancelRename(pet.id) }
                        )
                        .tag(pet.id)
                        .contextMenu {
                            Button("Rename") { beginRenaming(pet) }
                            Divider()
                            Button(pet.isVisible ? "Hide" : "Show") {
                                store.updatePetVisibility(pet.id, isVisible: !pet.isVisible)
                            }
                            Button("Respawn") { respawnPet(pet.id) }
                            Button("Duplicate") { store.duplicatePet(pet.id) }
                            Divider()
                            Button("Delete", role: .destructive) { store.removePet(pet.id) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button { store.addPet() } label: {
                    Label("Add Pet", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Pet")
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var selectedPetBinding: Binding<PetInstance.ID?> {
        Binding(
            get: { store.selectedPetInstanceID },
            set: { selectedID in
                guard let selectedID else { return }
                store.selectPetInstance(selectedID)
            }
        )
    }

    private func beginRenaming(_ pet: PetInstance) {
        store.selectPetInstance(pet.id)
        renameDraft = pet.name
        petBeingRenamedID = pet.id
    }

    private func commitRename(_ id: PetInstance.ID) {
        guard petBeingRenamedID == id else { return }
        store.updatePetName(id, name: renameDraft)
        petBeingRenamedID = nil
        renameDraft = ""
    }

    private func cancelRename(_ id: PetInstance.ID) {
        guard petBeingRenamedID == id else { return }
        petBeingRenamedID = nil
        renameDraft = ""
    }
}

private struct PetSidebarRow: View {
    let pet: PetInstance
    let isRenaming: Bool
    @Binding var renameDraft: String
    let commitRename: () -> Void
    let cancelRename: () -> Void
    @FocusState private var isRenameFieldFocused: Bool
    @State private var isCancellingRename = false

    var body: some View {
        HStack(spacing: 10) {
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
            .frame(width: 34, height: 34)

            if isRenaming {
                TextField("Pet name", text: $renameDraft)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .focused($isRenameFieldFocused)
                    .onSubmit(commitRename)
                    .onExitCommand {
                        isCancellingRename = true
                        cancelRename()
                    }
                    .onAppear {
                        isCancellingRename = false
                        isRenameFieldFocused = true
                        DispatchQueue.main.async {
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        }
                    }
                    .onChange(of: isRenameFieldFocused) { _, isFocused in
                        if !isFocused && isRenaming && !isCancellingRename {
                            commitRename()
                        }
                    }
            } else {
                Text(pet.name)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
