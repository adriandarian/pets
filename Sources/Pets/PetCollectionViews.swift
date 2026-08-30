import AppKit
import PetsCore
import SwiftUI

struct PetCollectionView: View {
    @ObservedObject var store: PetStore
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pet Collection")
                            .font(.title2.weight(.semibold))
                        Text("Discover every pet family and see which companions you have unlocked.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(selectedFamilyOwnedCount) of \(selectedCategory.petIDs.count) obtained")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Pet family", selection: $selectedCategoryID) {
                    ForEach(PetCatalog.builtInCategories, id: \.id) { category in
                        Text(category.displayName)
                            .tag(Optional(category.id))
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 142), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(selectedCategory.petIDs, id: \.self) { petID in
                        PetCollectionCard(store: store, petID: petID)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var selectedCategory: PetCatalogCategory {
        PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
            ?? PetCatalog.builtInCategories[0]
    }

    private var selectedFamilyOwnedCount: Int {
        selectedCategory.petIDs.count(where: store.isPetOwned)
    }
}

private struct PetCollectionCard: View {
    @ObservedObject var store: PetStore
    let petID: PetID

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.secondary.opacity(isOwned ? 0.08 : 0.045))

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
                .frame(width: 78, height: 78)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.34)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(systemName: isOwned ? "checkmark.circle.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOwned ? Color.accentColor : Color.secondary)
                    .padding(7)
                    .accessibilityLabel(isOwned ? "Obtained" : "Missing")
            }
            .frame(height: 92)

            Text(PetCatalog.displayName(for: petID))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isOwned {
                Label("Obtained", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 22)
            } else {
                Label(
                    "Missing · \(PetCatalog.rarity(for: petID).displayName)",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 22)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var isOwned: Bool {
        store.isPetOwned(petID)
    }
}
