import AppKit
import PetsCore
import SwiftUI

struct PetCollectionView: View {
    @ObservedObject var store: PetStore
    @State private var selectedCategoryID = PetCatalog.builtInCategories.first?.id
    @State private var familySearch = ""

    var body: some View {
        HSplitView {
            familySidebar
                .frame(width: 220)

            familyDetail
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: familySearch) { _, _ in
            guard !filteredCategories.isEmpty else { return }
            if !filteredCategories.contains(where: { $0.id == selectedCategoryID }) {
                selectedCategoryID = filteredCategories[0].id
            }
        }
    }

    private var familySidebar: some View {
        VStack(spacing: 0) {
            familySearchField
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, category in
                        PetFamilySidebarRow(
                            category: category,
                            ownedCount: ownedCount(in: category),
                            isSelected: selectedCategoryID == category.id,
                            select: { selectedCategoryID = category.id }
                        )

                        if index < filteredCategories.count - 1 {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }

                    if filteredCategories.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                            Text("No pet families found")
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
        }
        .background(.regularMaterial)
    }

    private var familySearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $familySearch)
                .textFieldStyle(.plain)

            if !familySearch.isEmpty {
                Button {
                    familySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear family search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.62))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search pet families")
    }

    private var familyDetail: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selectedCategory.displayName)
                        .font(.title.weight(.semibold))

                    Spacer(minLength: 20)

                    Text("\(selectedFamilyOwnedCount) of \(selectedCategory.petIDs.count) obtained")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: petGridColumns,
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(selectedCategory.petIDs, id: \.self) { petID in
                        PetCollectionCard(store: store, petID: petID)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var filteredCategories: [PetCatalogCategory] {
        let query = familySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return PetCatalog.builtInCategories }

        return PetCatalog.builtInCategories.filter { category in
            category.displayName.localizedStandardContains(query)
                || category.petIDs.contains { petID in
                    PetCatalog.displayName(for: petID).localizedStandardContains(query)
                }
        }
    }

    private var petGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 100, maximum: 210), spacing: 14),
            count: 5
        )
    }

    private var selectedCategory: PetCatalogCategory {
        PetCatalog.builtInCategories.first { $0.id == selectedCategoryID }
            ?? PetCatalog.builtInCategories[0]
    }

    private var selectedFamilyOwnedCount: Int {
        ownedCount(in: selectedCategory)
    }

    private func ownedCount(in category: PetCatalogCategory) -> Int {
        category.petIDs.count(where: store.isPetOwned)
    }
}

private struct PetFamilySidebarRow: View {
    let category: PetCatalogCategory
    let ownedCount: Int
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                PetSprite(
                    petID: representativePetID,
                    visualContext: PetVisualContext(
                        status: .idle,
                        hasActiveSessions: true,
                        isHovered: false,
                        animationSettings: .default
                    ),
                    pixelation: .off
                )
                .frame(width: 38, height: 38)

                Text(category.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(ownedCount)/\(category.petIDs.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
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
        }
        .buttonStyle(.plain)
        .help(category.displayName)
        .accessibilityLabel("\(category.displayName), \(ownedCount) of \(category.petIDs.count) obtained")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var representativePetID: PetID {
        category.petIDs.first ?? PetCatalog.defaultPetID
    }
}

private struct PetCollectionCard: View {
    @ObservedObject var store: PetStore
    let petID: PetID

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                .frame(width: 82, height: 82)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.34)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(systemName: isOwned ? "checkmark.circle.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOwned ? Color.accentColor : Color.secondary)
                    .padding(7)
                    .accessibilityLabel(isOwned ? "Obtained" : "Missing")
            }
            .frame(height: 102)

            Text(PetCatalog.displayName(for: petID))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isOwned {
                Label("Obtained", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 20)
            } else {
                Label(
                    "Missing · \(PetCatalog.rarity(for: petID).displayName)",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 20)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var isOwned: Bool {
        store.isPetOwned(petID)
    }
}
