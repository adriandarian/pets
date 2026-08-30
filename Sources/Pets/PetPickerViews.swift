import AppKit
import PetsCore
import SwiftUI

private struct PetPickerSheet: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose a Pet")
                    .font(.title2.bold())
                Text("Choose a pet from any family you have unlocked.")
                    .foregroundStyle(.secondary)
            }

            Picker("Pet family", selection: $selectedCategoryID) {
                ForEach(PetCatalog.builtInCategories, id: \.id) { category in
                    Text(category.displayName)
                        .tag(Optional(category.id))
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(selectedCategory.petIDs, id: \.self) { petID in
                        PetPickerCard(
                            petID: petID,
                            isSelected: petID == store.selectedPetInstance?.petID,
                            isOwned: store.isPetOwned(petID)
                        ) {
                            store.updateSelectedPetID(petID)
                            isPresented = false
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 820, height: 560)
        .onAppear {
            selectedCategoryID = store.selectedPetInstance
                .flatMap { PetCatalog.category(for: $0.petID)?.id }
                ?? selectedCategoryID
        }
    }

    private var selectedCategory: PetCatalogCategory {
        PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
            ?? PetCatalog.builtInCategories[0]
    }
}

struct PetPickerOverlay: View {
    @ObservedObject var store: PetStore
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            PetPickerSheet(store: store, isPresented: $isPresented)
                .background {
                    Color(nsColor: .windowBackgroundColor)
                    PetWindowOutsideClickMonitor { isPresented = false }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        }
        .onExitCommand { isPresented = false }
    }
}

private struct PetPickerCard: View {
    let petID: PetID
    let isSelected: Bool
    let isOwned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary.opacity(0.6))
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
                    .frame(width: 94, height: 94)
                }
                .frame(height: 120)

                Text(PetCatalog.displayName(for: petID))
                    .font(.headline)
                    .lineLimit(1)
                if !isOwned {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)
        .opacity(isOwned ? 1 : 0.58)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
        }
    }
}
