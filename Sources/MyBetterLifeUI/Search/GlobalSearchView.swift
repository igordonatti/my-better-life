import SwiftUI
import MyBetterLifeCore

/// Global search view across block titles, rich note text, checklists, and recurring series.
public struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss

    public let store: PlannerStore
    @Binding public var query: String
    public let onSelectResult: (GlobalSearchResult) -> Void

    @FocusState private var isSearchFocused: Bool

    public init(
        store: PlannerStore,
        query: Binding<String>,
        onSelectResult: @escaping (GlobalSearchResult) -> Void
    ) {
        self.store = store
        self._query = query
        self.onSelectResult = onSelectResult
    }

    private var results: [GlobalSearchResult] {
        SearchEngine.search(
            query: query,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.searchPlaceholder, text: $query)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isSearchFocused)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding()

                Divider()

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        L10n.searchTitle,
                        systemImage: "magnifyingglass",
                        description: Text(L10n.searchPrompt)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        L10n.searchEmpty,
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Tente buscar por outra palavra no título ou nas notas.")
                    )
                } else {
                    List(results) { item in
                        Button {
                            onSelectResult(item)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: item.category?.colorHex ?? AppTheme.defaultAccentHex))
                                    .frame(width: 4, height: 38)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if item.note != nil {
                                            Image(systemName: "doc.text")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if item.isRecurringTemplate {
                                            Image(systemName: "repeat")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(AppTheme.shortDate(item.targetDate))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }

                                    if !item.snippet.isEmpty {
                                        Text(item.snippet)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L10n.searchTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isSearchFocused = true
                }
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 460)
        #endif
    }
}
