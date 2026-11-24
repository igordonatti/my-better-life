import SwiftUI
import MyBetterLifeCore

/// Spotlight / Raycast-style `⌘K` Command Palette:
/// - Full keyboard navigation (`↑`, `↓`, `↵`, `Esc`) on macOS
/// - Portuguese natural-language date jumps ("hoje", "amanha", "sexta", "25/11", "+3")
/// - Quick actions, Global Blocks (Second Brain), Inbox items, Notes, and Timeline Blocks
public struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss

    public let store: PlannerStore
    @Binding public var query: String
    public let onSelectItem: (PaletteItem) -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex: Int = 0

    public init(
        store: PlannerStore,
        query: Binding<String>,
        onSelectItem: @escaping (PaletteItem) -> Void
    ) {
        self.store = store
        self._query = query
        self.onSelectItem = onSelectItem
    }

    private var items: [PaletteItem] {
        #if os(macOS)
        let includeSplit = true
        #else
        let includeSplit = false
        #endif
        return CommandPaletteEngine.results(
            query: query,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            inboxItems: store.inboxItems,
            categories: store.categories,
            includeSplitDayOption: includeSplit
        )
    }

    /// Groups items in display order while preserving their flat index for `↑`/`↓` navigation.
    private var groupedSections: [(section: PaletteSectionKind, entries: [(index: Int, item: PaletteItem)])] {
        var order: [PaletteSectionKind] = []
        var map: [PaletteSectionKind: [(Int, PaletteItem)]] = [:]
        for (idx, item) in items.enumerated() {
            if map[item.section] == nil {
                order.append(item.section)
                map[item.section] = []
            }
            map[item.section]?.append((idx, item))
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            resultsList
            #if os(macOS)
            Divider()
            keyboardHintsFooter
            #endif
        }
        .background(AppTheme.canvasBackground)
        #if os(macOS)
        .frame(width: 580, height: 480)
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        #endif
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onAppear {
            selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                isSearchFocused = true
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(L10n.commandPalettePlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)
                .onSubmit {
                    executeSelected()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                dismiss()
            } label: {
                Text("esc")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if items.isEmpty {
                        ContentUnavailableView(
                            L10n.searchEmpty,
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Tente uma palavra, data (ex.: \"amanhã\", \"sexta\") ou ação.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        ForEach(groupedSections, id: \.section) { group in
                            Text(group.section.rawValue.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            ForEach(group.entries, id: \.item.id) { entry in
                                paletteRow(item: entry.item, isSelected: entry.index == selectedIndex)
                                    .id(entry.index)
                                    .onTapGesture {
                                        selectedIndex = entry.index
                                        executeItem(entry.item)
                                    }
                                    #if os(macOS)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedIndex = entry.index
                                        }
                                    }
                                    #endif
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .onChange(of: selectedIndex) { _, newIdx in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
            }
        }
    }

    private func paletteRow(item: PaletteItem, isSelected: Bool) -> some View {
        let iconColor: Color = item.accentHex.map { Color(hex: $0) }
            ?? (item.section == .dates ? Color.accentColor : .secondary)

        return HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? iconColor.opacity(0.20) : AppTheme.secondarySurface)
                    .frame(width: 28, height: 28)

                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? iconColor : iconColor.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let badge = item.trailingBadge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        (isSelected ? Color.accentColor.opacity(0.14) : AppTheme.secondarySurface),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.11))
            }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    #if os(macOS)
    private var keyboardHintsFooter: some View {
        HStack(spacing: 14) {
            hintChip(keys: "↑↓", label: "Navegar")
            hintChip(keys: "↵", label: "Abrir / Executar")
            hintChip(keys: "esc", label: "Fechar")
            Spacer()
            Text("Dica: digite \"amanhã\", \"sexta\" ou \"25/11\"")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.secondarySurface.opacity(0.45))
    }

    private func hintChip(keys: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(AppTheme.canvasBackground, in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    #endif

    private func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let next = (selectedIndex + delta + items.count) % items.count
        selectedIndex = next
    }

    private func executeSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        executeItem(items[selectedIndex])
    }

    private func executeItem(_ item: PaletteItem) {
        onSelectItem(item)
        dismiss()
    }
}
