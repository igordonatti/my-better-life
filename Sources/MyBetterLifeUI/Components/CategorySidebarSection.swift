import SwiftUI
import MyBetterLifeCore

/// Sidebar section displaying customizable categories with filtering and create/edit controls.
public struct CategorySidebarSection: View {
    public let store: PlannerStore
    @Binding public var selectedFilterID: UUID?

    @State private var editingCategory: BlockCategory? = nil
    @State private var isCreatingCategory: Bool = false

    public init(
        store: PlannerStore,
        selectedFilterID: Binding<UUID?>
    ) {
        self.store = store
        self._selectedFilterID = selectedFilterID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.categoriesSection.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Spacer()
                Button {
                    isCreatingCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.newCategory)
            }
            .padding(.horizontal, 6)

            filterRow(
                title: L10n.allCategories,
                symbol: "square.grid.2x2",
                color: .secondary,
                isSelected: selectedFilterID == nil
            ) {
                selectedFilterID = nil
            }

            ForEach(store.categories) { category in
                filterRow(
                    title: category.name,
                    symbol: category.symbolName,
                    color: Color(hex: category.colorHex),
                    isSelected: selectedFilterID == category.id
                ) {
                    if selectedFilterID == category.id {
                        selectedFilterID = nil
                    } else {
                        selectedFilterID = category.id
                    }
                }
                .contextMenu {
                    Button {
                        editingCategory = category
                    } label: {
                        Label(L10n.editCategory, systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        if selectedFilterID == category.id {
                            selectedFilterID = nil
                        }
                        store.deleteCategory(id: category.id)
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingCategory) {
            CategoryEditorSheet(store: store, category: nil, nextSortOrder: store.categories.count)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(store: store, category: category, nextSortOrder: category.sortOrder)
        }
    }

    private func filterRow(
        title: String,
        symbol: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Modal sheet for creating or editing a customizable BlockCategory.
public struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let store: PlannerStore
    public let category: BlockCategory?
    public let nextSortOrder: Int

    @State private var name: String
    @State private var colorHex: String
    @State private var symbolName: String

    public init(store: PlannerStore, category: BlockCategory?, nextSortOrder: Int) {
        self.store = store
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _colorHex = State(initialValue: category?.colorHex ?? BlockCategory.curatedPalette[0])
        _symbolName = State(initialValue: category?.symbolName ?? BlockCategory.curatedSymbols[0])
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identidade") {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: colorHex).opacity(0.18))
                                .frame(width: 38, height: 38)
                            Image(systemName: symbolName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(hex: colorHex))
                        }
                        TextField("Nome da categoria (ex: Trabalho)", text: $name)
                            .textFieldStyle(.plain)
                            .font(.body)
                    }
                }

                Section("Cor") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(BlockCategory.curatedPalette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                    if colorHex == hex {
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: 2.5)
                                            .frame(width: 36, height: 36)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Ícone") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(BlockCategory.curatedSymbols, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(symbolName == symbol ? Color(hex: colorHex) : .secondary)
                                    .frame(width: 32, height: 32)
                                    .background {
                                        if symbolName == symbol {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color(hex: colorHex).opacity(0.16))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(category == nil ? L10n.newCategory : L10n.editCategory)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if var existing = category {
                            existing.name = trimmed
                            existing.colorHex = colorHex
                            existing.symbolName = symbolName
                            store.upsertCategory(existing)
                        } else {
                            let newCat = BlockCategory(
                                name: trimmed,
                                colorHex: colorHex,
                                symbolName: symbolName,
                                sortOrder: nextSortOrder
                            )
                            store.upsertCategory(newCat)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 380, height: 420)
        #endif
    }
}
