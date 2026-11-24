import SwiftUI
import UniformTypeIdentifiers
import MyBetterLifeCore

/// Drag payload for reparenting a note onto another note in the hierarchical Notes tree on macOS.
private enum NoteHierarchyDragPayload {
    static let prefix = "mbl-note:"

    static func encode(_ noteID: UUID) -> String {
        "\(prefix)\(noteID.uuidString)"
    }

    static func decode(_ string: String) -> UUID? {
        guard string.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(string.dropFirst(prefix.count)))
    }
}

private struct HierarchicalNoteRow: Identifiable {
    let item: UnifiedNoteItem
    let depth: Int
    let directChildCount: Int

    var id: String { item.id }
}

/// Complete Notes workspace (Apple Notes / Bear / Notion style) showing hierarchical `.md` notes
/// (parent notes -> multi-level subnotes), Global Blocks, and non-empty agenda notes.
public struct NotesWorkspaceView: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel

    @State private var isImportPresented: Bool = false
    @State private var exportDocument: MarkdownFileDocument? = nil
    @State private var exportFilename: String = "nota.md"
    @State private var isExportPresented: Bool = false
    @State private var phoneNavSelection: String? = nil
    @State private var collapsedParentIDs: Set<UUID> = []
    @State private var dropTargetNoteID: UUID? = nil
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init(store: PlannerStore, viewModel: PlannerViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var filteredItems: [UnifiedNoteItem] {
        NotesLibraryEngine.items(
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories,
            attachments: store.attachments,
            originFilter: viewModel.notesOriginFilter,
            filterDay: viewModel.notesFilterByDay ? viewModel.selectedDate : nil,
            categoryFilterID: viewModel.selectedCategoryFilterID,
            searchQuery: viewModel.notesSearchQuery
        )
    }

    private var shouldRenderHierarchyTree: Bool {
        viewModel.notesSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.notesFilterByDay
            && viewModel.notesOriginFilter != .agendaOnly
    }

    private var displayedRows: [HierarchicalNoteRow] {
        guard shouldRenderHierarchyTree else {
            return filteredItems.map { HierarchicalNoteRow(item: $0, depth: 0, directChildCount: 0) }
        }

        let standaloneItems = filteredItems.filter { $0.standaloneNote != nil }
        let standaloneIDs = Set(standaloneItems.compactMap { $0.standaloneNote?.id })
        let childrenByParent: [UUID: [UnifiedNoteItem]] = Dictionary(
            grouping: standaloneItems.filter { item in
                guard let pid = item.standaloneNote?.parentNoteID else { return false }
                return standaloneIDs.contains(pid)
            },
            by: { $0.standaloneNote!.parentNoteID! }
        )

        var rows: [HierarchicalNoteRow] = []
        var visited: Set<String> = []

        func appendNode(_ item: UnifiedNoteItem, depth: Int) {
            guard !visited.contains(item.id) else { return }
            visited.insert(item.id)
            let noteID = item.standaloneNote?.id
            let kids = noteID.flatMap { childrenByParent[$0] } ?? []
            rows.append(HierarchicalNoteRow(item: item, depth: depth, directChildCount: kids.count))

            if let nid = noteID, !kids.isEmpty, !collapsedParentIDs.contains(nid) {
                for child in kids {
                    appendNode(child, depth: depth + 1)
                }
            }
        }

        for item in filteredItems {
            if let note = item.standaloneNote, let pid = note.parentNoteID, standaloneIDs.contains(pid) {
                // Rendered recursively under its parent
                continue
            }
            appendNode(item, depth: 0)
        }
        return rows
    }

    private var selectedNoteItem: UnifiedNoteItem? {
        guard let id = viewModel.selectedNoteItemID else { return nil }
        return filteredItems.first(where: { $0.id == id })
            ?? NotesLibraryEngine.items(
                notes: store.notes,
                blocks: store.blocks,
                categories: store.categories,
                attachments: store.attachments,
                originFilter: .all
            ).first(where: { $0.id == id })
    }

    public var body: some View {
        Group {
            #if os(macOS)
            HStack(spacing: 0) {
                notesListPane
                    .frame(minWidth: 270, idealWidth: 310, maxWidth: 350, maxHeight: .infinity)

                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 0.75)

                noteEditorPane
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            NavigationStack {
                notesListPane
                    .navigationTitle(L10n.notesTab)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(item: $phoneNavSelection) { itemID in
                        if let item = filteredItems.first(where: { $0.id == itemID }) {
                            UnifiedNoteEditorView(
                                store: store,
                                item: item,
                                viewModel: viewModel,
                                onExport: { triggerExport(for: item) }
                            )
                            .navigationTitle(item.title.isEmpty ? L10n.untitledNote : item.title)
                            .navigationBarTitleDisplayMode(.inline)
                        }
                    }
            }
            #endif
        }
        .background(AppTheme.canvasBackground)
        .fileImporter(
            isPresented: $isImportPresented,
            allowedContentTypes: [.markdownDocument, .plainText],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    let fileTitle = url.deletingPathExtension().lastPathComponent
                    viewModel.importMarkdownNote(title: fileTitle, markdown: text, in: store)
                }
            }
        }
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .markdownDocument,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
    }

    // MARK: - Left Notes List Pane

    private var notesListPane: some View {
        VStack(spacing: 0) {
            listHeader
            filtersBar
            Divider()

            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(L10n.notesEmptyTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(L10n.notesEmptySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                    Button {
                        createNewNote()
                    } label: {
                        Label(L10n.newNote, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 5) {
                        ForEach(displayedRows) { row in
                            noteRow(for: row)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(AppTheme.canvasBackground)
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            Text(L10n.notesTab)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text("\(filteredItems.count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.secondarySurface, in: Capsule())

            Spacer()

            Button {
                isImportPresented = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.importMarkdown)

            Button {
                createNewNote()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(L10n.newNote)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var filtersBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Inline search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.notesSearchPlaceholder, text: $viewModel.notesSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !viewModel.notesSearchQuery.isEmpty {
                    Button {
                        viewModel.notesSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(AppTheme.secondarySurface.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Origin filter (Todas / Avulsas / Agenda)
            Picker("Origem", selection: $viewModel.notesOriginFilter) {
                ForEach(NoteOriginFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Day filter toggle chip (synced with Mini-Calendário!)
            HStack(spacing: 6) {
                Button {
                    viewModel.notesFilterByDay.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption2.weight(.semibold))
                        if viewModel.notesFilterByDay {
                            Text(AppTheme.shortDate(viewModel.selectedDate))
                                .font(.caption.weight(.semibold))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        } else {
                            Text(L10n.notesFilterByDay)
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(viewModel.notesFilterByDay ? .white : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(viewModel.notesFilterByDay ? Color.accentColor : AppTheme.secondarySurface)
                    )
                }
                .buttonStyle(.plain)

                if viewModel.selectedCategoryFilterID != nil,
                   let cat = store.category(for: viewModel.selectedCategoryFilterID) {
                    Button {
                        viewModel.selectedCategoryFilterID = nil
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 6, height: 6)
                            Text(cat.name)
                                .font(.caption.weight(.medium))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: cat.colorHex).opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func noteRow(for row: HierarchicalNoteRow) -> some View {
        let item = row.item
        let isSelected = viewModel.selectedNoteItemID == item.id
        let accent = Color(hex: item.category?.colorHex ?? AppTheme.defaultAccentHex)
        let summary = item.summary
        let noteID = item.standaloneNote?.id
        let isCollapsed = noteID.map { collapsedParentIDs.contains($0) } ?? false
        let isDropTarget = noteID != nil && dropTargetNoteID == noteID
        let ancestorTrail: String = {
            guard !shouldRenderHierarchyTree, let note = item.standaloneNote else { return "" }
            let ancestors = SecondBrainEngine.ancestorPath(for: note, in: store.notes)
            guard !ancestors.isEmpty else { return "" }
            return ancestors.map { $0.title.isEmpty ? L10n.untitledNote : $0.title }.joined(separator: " › ")
        }()

        return HStack(spacing: 0) {
            if row.depth > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: CGFloat(min(row.depth, 5)) * 14 - 8)
                    Rectangle()
                        .fill(AppTheme.hairline.opacity(0.65))
                        .frame(width: 1.5)
                        .padding(.vertical, 4)
                    Spacer().frame(width: 6.5)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                if !ancestorTrail.isEmpty {
                    Text(ancestorTrail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack(alignment: .center, spacing: 6) {
                    if row.directChildCount > 0, let nid = noteID {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if collapsedParentIDs.contains(nid) {
                                    collapsedParentIDs.remove(nid)
                                } else {
                                    collapsedParentIDs.insert(nid)
                                }
                            }
                        } label: {
                            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if item.isGlobal {
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    } else {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                    }

                    Text(item.title.isEmpty ? L10n.untitledNote : item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if row.directChildCount > 0 {
                        Text("\(row.directChildCount)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.canvasBackground.opacity(0.8), in: Capsule())
                    }

                    Spacer(minLength: 4)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                    }

                    if item.isGlobal {
                        Text("Global")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.14), in: Capsule())
                    } else if item.isFromAgenda {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9, weight: .semibold))
                            Text(AppTheme.shortDate(item.referenceDate))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.secondarySurface, in: Capsule())
                    } else {
                        Text(AppTheme.shortDate(item.updatedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !summary.previewText.isEmpty {
                    Text(summary.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(row.depth > 0 ? 1 : 2)
                }

                if summary.checklist.hasItems || summary.imageCount > 0 || summary.linkCount > 0 {
                    HStack(spacing: 8) {
                        if summary.checklist.hasItems {
                            HStack(spacing: 3) {
                                Image(systemName: summary.checklist.isAllCompleted ? "checkmark.square.fill" : "checklist")
                                    .font(.system(size: 10))
                                Text("\(summary.checklist.completed)/\(summary.checklist.total)")
                                    .font(.caption2.weight(.medium).monospacedDigit())
                            }
                            .foregroundStyle(summary.checklist.isAllCompleted ? accent : .secondary)
                        }
                        if summary.imageCount > 0 {
                            Label("\(summary.imageCount)", systemImage: "photo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if summary.linkCount > 0 {
                            Image(systemName: "link")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, row.depth > 0 ? 7 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isDropTarget ? Color.accentColor.opacity(0.16) : (isSelected ? accent.opacity(0.14) : AppTheme.secondarySurface.opacity(0.45)))
            )
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.6, dash: [5, 3]))
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(accent.opacity(0.55), lineWidth: 1.2)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectNoteItem(item)
            #if os(iOS)
            phoneNavSelection = item.id
            #endif
        }
        #if os(macOS)
        .onDrag {
            guard let nid = noteID else { return NSItemProvider() }
            return NSItemProvider(object: NoteHierarchyDragPayload.encode(nid) as NSString)
        }
        .onDrop(of: [.utf8PlainText, .plainText, .text], isTargeted: Binding(
            get: { isDropTarget },
            set: { targeted in
                guard let nid = noteID else { return }
                dropTargetNoteID = targeted ? nid : (dropTargetNoteID == nid ? nil : dropTargetNoteID)
            }
        )) { providers in
            guard let targetID = noteID else { return false }
            for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let str = object as? String,
                          let draggedID = NoteHierarchyDragPayload.decode(str) else { return }
                    Task { @MainActor in
                        if let draggedNote = store.note(for: draggedID) {
                            viewModel.moveNote(draggedNote, toParentID: targetID, in: store)
                            collapsedParentIDs.remove(targetID)
                        }
                    }
                }
                return true
            }
            return false
        }
        #endif
        .contextMenu {
            if let note = item.standaloneNote {
                #if os(macOS)
                Button {
                    openWindow(id: DetachedEditorTarget.windowID, value: DetachedEditorTarget.standaloneNote(note.id))
                } label: {
                    Label("Abrir em nova janela", systemImage: "arrow.up.forward.app")
                }
                #endif

                Button {
                    collapsedParentIDs.remove(note.id)
                    let created = viewModel.createSubnote(
                        title: "",
                        parentNote: note,
                        appendWikiLinkToParent: false,
                        openCreated: true,
                        in: store
                    )
                    #if os(iOS)
                    if let created { phoneNavSelection = "note-\(created.id.uuidString)" }
                    #else
                    _ = created
                    #endif
                } label: {
                    Label("Nova subnota aqui", systemImage: "doc.badge.plus")
                }

                Menu {
                    Button {
                        viewModel.moveNote(note, toParentID: nil, in: store)
                    } label: {
                        Label("Raiz (sem nota pai)", systemImage: note.parentNoteID == nil ? "checkmark" : "arrow.up.to.line")
                    }

                    Divider()

                    let candidates = store.notes
                        .filter { SecondBrainEngine.canReparent(noteID: note.id, toParentID: $0.id, in: store.notes) }
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

                    ForEach(candidates) { target in
                        Button {
                            viewModel.moveNote(note, toParentID: target.id, in: store)
                            collapsedParentIDs.remove(target.id)
                        } label: {
                            Label(
                                target.title.isEmpty ? L10n.untitledNote : target.title,
                                systemImage: note.parentNoteID == target.id ? "checkmark" : (target.isGlobal ? "globe" : "doc.text")
                            )
                        }
                    }
                } label: {
                    Label("Mover para…", systemImage: "folder")
                }

                Divider()

                Button {
                    viewModel.toggleGlobalFlag(for: note, in: store)
                } label: {
                    Label(note.isGlobal ? "Remover de Blocos Globais" : L10n.makeGlobalBlock, systemImage: "globe")
                }

                Button {
                    viewModel.togglePin(for: note, in: store)
                } label: {
                    Label(note.isPinned ? L10n.unpinNote : L10n.pinNote, systemImage: note.isPinned ? "pin.slash" : "pin")
                }

                Button {
                    if note.isGlobal {
                        viewModel.scheduleGlobalBlock(note, on: viewModel.selectedDate, in: store)
                    } else {
                        viewModel.scheduleStandaloneNoteToday(note, in: store)
                    }
                } label: {
                    Label(L10n.scheduleToday, systemImage: "calendar.badge.plus")
                }
            } else if let block = item.agendaBlock {
                Button {
                    viewModel.jumpToAgendaBlock(block)
                } label: {
                    Label(L10n.viewInAgenda, systemImage: "calendar")
                }
            }

            Button {
                triggerExport(for: item)
            } label: {
                Label(L10n.exportMarkdown, systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteNoteItem(item, in: store)
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    // MARK: - Right Full-Width Markdown Editor Pane (macOS)

    #if os(macOS)
    private var noteEditorPane: some View {
        Group {
            if let item = selectedNoteItem {
                UnifiedNoteEditorView(
                    store: store,
                    item: item,
                    viewModel: viewModel,
                    onExport: { triggerExport(for: item) }
                )
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(L10n.notesSelectPromptTitle)
                        .font(.headline)
                    Text(L10n.notesSelectPromptSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                    Button {
                        createNewNote()
                    } label: {
                        Label(L10n.newNote, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvasBackground)
            }
        }
    }
    #endif

    // MARK: - Helpers

    private func createNewNote() {
        let note = viewModel.createStandaloneNote(in: store)
        #if os(iOS)
        phoneNavSelection = "note-\(note.id.uuidString)"
        #else
        _ = note
        #endif
    }

    private func triggerExport(for item: UnifiedNoteItem) {
        exportDocument = MarkdownFileDocument(title: item.title, markdown: item.noteMarkdown)
        exportFilename = MarkdownFileDocument.sanitizedFilename(from: item.title)
        isExportPresented = true
    }
}

/// Full-width Markdown editor for either a `StandaloneNote` or an Agenda `TimeBlock`'s note,
/// reusing the exact same live MD <-> Formatted editor and bidirectional Agenda link!
public struct UnifiedNoteEditorView: View {
    public let store: PlannerStore
    public let item: UnifiedNoteItem
    @Bindable public var viewModel: PlannerViewModel
    public let isDetachedWindow: Bool
    public let onExport: () -> Void

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var titleDraft: String = ""
    @FocusState private var isTitleFocused: Bool

    public init(
        store: PlannerStore,
        item: UnifiedNoteItem,
        viewModel: PlannerViewModel,
        isDetachedWindow: Bool = false,
        onExport: @escaping () -> Void
    ) {
        self.store = store
        self.item = item
        self.viewModel = viewModel
        self.isDetachedWindow = isDetachedWindow
        self.onExport = onExport
    }

    private var accentColor: Color {
        Color(hex: item.category?.colorHex ?? AppTheme.defaultAccentHex)
    }

    private var currentAttachments: [BlockAttachment] {
        switch item.source {
        case .standalone(let note):
            return store.attachments(forNoteID: note.id)
        case .agendaBlock(let block):
            return store.attachments(forBlockID: block.id)
        }
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                if let standalone = item.standaloneNote {
                    NoteBreadcrumbBar(
                        store: store,
                        viewModel: viewModel,
                        currentNote: standalone,
                        accentColor: accentColor
                    )
                }
                titleHeader
                connectionAndCategoryBar
                RichNoteEditorView(
                    markdown: Binding(
                        get: { item.noteMarkdown },
                        set: { newMarkdown in
                            viewModel.updateUnifiedNoteMarkdown(newMarkdown, for: item, in: store)
                        }
                    ),
                    attachments: currentAttachments,
                    accentColor: accentColor,
                    availableWikiTargets: store.notes,
                    excludingNoteID: item.standaloneNote?.id,
                    onToggleChecklistLine: { lineIndex in
                        viewModel.toggleUnifiedNoteChecklistLine(at: lineIndex, for: item, in: store)
                    },
                    onAttachImage: { data, fileName in
                        viewModel.attachImage(rawData: data, fileName: fileName, to: item, in: store)
                    },
                    onRemoveAttachment: { attachment in
                        viewModel.removeAttachment(attachment, from: item, in: store)
                    },
                    onOpenWikiLink: { targetTitle in
                        viewModel.openOrCreateWikiLink(
                            title: targetTitle,
                            fromParentTitle: titleDraft,
                            fromParentNoteID: item.standaloneNote?.id,
                            in: store
                        )
                    },
                    onCreateSubnoteInline: item.standaloneNote.map { parentNote in
                        { newTitle in
                            _ = viewModel.createSubnote(
                                title: newTitle,
                                parentNote: parentNote,
                                appendWikiLinkToParent: false,
                                openCreated: false,
                                in: store
                            )
                        }
                    }
                )

                SecondBrainConnectionsView(
                    store: store,
                    viewModel: viewModel,
                    currentTitle: titleDraft,
                    currentNote: item.standaloneNote,
                    currentBlockID: item.agendaBlock?.id,
                    accentColor: accentColor
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvasBackground)
        .onAppear {
            titleDraft = item.title
            if viewModel.shouldFocusNoteTitleField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTitleFocused = true
                    viewModel.shouldFocusNoteTitleField = false
                }
            }
        }
        .onChange(of: item.id) { _, _ in
            titleDraft = item.title
            if viewModel.shouldFocusNoteTitleField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTitleFocused = true
                    viewModel.shouldFocusNoteTitleField = false
                }
            }
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            TextField(L10n.noteTitlePlaceholder, text: $titleDraft)
                .font(.title2.weight(.bold))
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onChange(of: titleDraft) { _, newValue in
                    guard newValue != item.title else { return }
                    viewModel.updateUnifiedNoteTitle(newValue, for: item, in: store)
                }

            if let note = item.standaloneNote {
                Button {
                    _ = viewModel.createSubnote(
                        title: "",
                        parentNote: note,
                        appendWikiLinkToParent: false,
                        openCreated: true,
                        in: store
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.caption.weight(.semibold))
                        Text("Subnota")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Criar nova subnota dentro desta nota")

                #if os(macOS)
                if !isDetachedWindow {
                    Button {
                        openWindow(id: DetachedEditorTarget.windowID, value: DetachedEditorTarget.standaloneNote(note.id))
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir em nova janela independente (estilo Slack)")
                }
                #endif

                Button {
                    viewModel.toggleGlobalFlag(for: note, in: store)
                } label: {
                    Image(systemName: "globe")
                        .font(.subheadline)
                        .foregroundStyle(note.isGlobal ? accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            note.isGlobal ? accentColor.opacity(0.14) : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(note.isGlobal ? "Bloco Global ativo (clique para desativar)" : L10n.makeGlobalBlock)

                Button {
                    viewModel.togglePin(for: note, in: store)
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.subheadline)
                        .foregroundStyle(note.isPinned ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            note.isPinned ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? L10n.unpinNote : L10n.pinNote)
            }

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.exportMarkdown)

            Button(role: .destructive) {
                viewModel.deleteNoteItem(item, in: store)
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L10n.delete)
        }
    }

    private var connectionAndCategoryBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bidirectional Agenda connection pill
            HStack(spacing: 8) {
                if let block = item.agendaBlock {
                    Button {
                        viewModel.jumpToAgendaBlock(block)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption2.weight(.semibold))
                            if block.isAllDay {
                                Text("\(L10n.viewInAgenda) · \(AppTheme.shortDate(block.startDate)) · \(L10n.allDay)")
                            } else {
                                Text("\(L10n.viewInAgenda) · \(AppTheme.shortDate(block.startDate)) · \(TimelineMath.formatTimeRange(start: block.startDate, end: block.endDate))")
                            }
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else if let note = item.standaloneNote {
                    Button {
                        if note.isGlobal {
                            viewModel.scheduleGlobalBlock(note, on: viewModel.selectedDate, in: store)
                        } else {
                            viewModel.scheduleStandaloneNoteToday(note, in: store)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.caption2.weight(.semibold))
                            Text(note.isGlobal ? "Agendar sessão hoje" : L10n.scheduleToday)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.secondarySurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Compact category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip(
                        title: L10n.noCategory,
                        symbol: "circle.dashed",
                        color: .secondary,
                        isSelected: item.category == nil
                    ) {
                        viewModel.updateUnifiedNoteCategory(nil, for: item, in: store)
                    }

                    ForEach(store.categories) { category in
                        categoryChip(
                            title: category.name,
                            symbol: category.symbolName,
                            color: Color(hex: category.colorHex),
                            isSelected: item.category?.id == category.id
                        ) {
                            viewModel.updateUnifiedNoteCategory(category.id, for: item, in: store)
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(
        title: String,
        symbol: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isSelected ? color : color.opacity(0.11)))
        }
        .buttonStyle(.plain)
    }
}
