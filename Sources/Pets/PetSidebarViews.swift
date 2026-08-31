import AppKit
import PetsCore
import SwiftUI

struct PetSidebar: View {
    @ObservedObject var store: PetStore
    let respawnPet: (PetInstance.ID) -> Void
    @State private var petBeingRenamedID: PetInstance.ID?
    @State private var renameDraft = ""
    @State private var petSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            PetSidebarSearchField(
                text: $petSearch,
                accessibilityLabel: "Search pets",
                clearButtonAccessibilityLabel: "Clear pet search"
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredPets.enumerated()), id: \.element.id) { index, pet in
                        PetSidebarRow(
                            pet: pet,
                            isSelected: store.selectedPetInstanceID == pet.id,
                            isRenaming: petBeingRenamedID == pet.id,
                            renameDraft: $renameDraft,
                            select: { store.selectPetInstance(pet.id) },
                            commitRename: { commitRename(pet.id) },
                            cancelRename: { cancelRename(pet.id) }
                        )
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

                        if index < filteredPets.count - 1 {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }

                    if filteredPets.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                            Text("No pets found")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            Divider()

            Button { store.addPet() } label: {
                Label("Add Pet", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .help("Add Pet")
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    private var filteredPets: [PetInstance] {
        let query = petSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.petInstances }

        return store.petInstances.filter { pet in
            pet.name.localizedStandardContains(query)
                || PetCatalog.displayName(for: pet.petID).localizedStandardContains(query)
        }
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
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameDraft: String
    let select: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    @FocusState private var isRenameFieldFocused: Bool
    @State private var isCancellingRename = false

    @ViewBuilder
    var body: some View {
        if isRenaming {
            rowContent
        } else {
            Button(action: select) {
                rowContent
            }
            .buttonStyle(.plain)
        }
    }

    private var rowContent: some View {
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
            .frame(width: 38, height: 38)

            if isRenaming {
                TextField("Pet name", text: $renameDraft)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.semibold))
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 66)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.58), lineWidth: 1)
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 50)
                    .padding(.leading, 1)
            }
        }
        .help(pet.name)
        .accessibilityLabel(pet.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
