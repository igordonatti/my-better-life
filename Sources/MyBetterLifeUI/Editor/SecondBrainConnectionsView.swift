import SwiftUI
import MyBetterLifeCore

/// Clickable Notion-style ancestor breadcrumb bar (e.g. `Estudos de SRE › Kubernetes › Networking`).
public struct NoteBreadcrumbBar: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel
    public let currentNote: StandaloneNote
    public let accentColor: Color

    public init(
        store: PlannerStore,
        viewModel: PlannerViewModel,
        currentNote: StandaloneNote,
        accentColor: Color
    ) {
        self.store = store
        self.viewModel = viewModel
        self.currentNote = currentNote
        self.accentColor = accentColor
    }

    private var ancestors: [StandaloneNote] {
        SecondBrainEngine.ancestorPath(for: currentNote, in: store.notes)
    }

    public var body: some View {
        if !ancestors.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(ancestors) { ancestor in
                        Button {
                            viewModel.openGlobalNoteInNotes(ancestor)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ancestor.isGlobal ? "globe" : "doc.text")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ancestor.isGlobal ? accentColor : .secondary)
                                Text(ancestor.title.isEmpty ? L10n.untitledNote : ancestor.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }

                    Text(currentNote.title.isEmpty ? L10n.untitledNote : currentNote.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Second-Brain hierarchy & connections panel displayed below the Markdown editor:
/// - Nested **Subnotas** (child pages inside this parent note, Notion-style) with inline "+ Subnota" creation
/// - Outgoing `[[wikilinks]]` citations
/// - Automatic Backlinks ("Mencionado em…") across all notes & agenda blocks
/// - Scheduled Agenda sessions history for Global Blocks
public struct SecondBrainConnectionsView: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel
    public let currentTitle: String
    public let currentNote: StandaloneNote?
    public let currentBlockID: UUID?
    public let accentColor: Color

    @State private var isCreatingSubnote: Bool = false
    @State private var newSubnoteTitle: String = ""
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init(
        store: PlannerStore,
        viewModel: PlannerViewModel,
        currentTitle: String,
        currentNote: StandaloneNote?,
        currentBlockID: UUID? = nil,
        accentColor: Color
    ) {
        self.store = store
        self.viewModel = viewModel
        self.currentTitle = currentTitle
        self.currentNote = currentNote
        self.currentBlockID = currentBlockID
        self.accentColor = accentColor
    }

    private var childSubnotes: [StandaloneNote] {
        guard let note = currentNote else { return [] }
        return SecondBrainEngine.childNotes(of: note.id, in: store.notes)
    }

    private var backlinks: [BacklinkReference] {
        SecondBrainEngine.backlinks(
            forTitle: currentTitle,
            excludingNoteID: currentNote?.id,
            excludingBlockID: currentBlockID,
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories
        )
    }

    private var sessions: [GlobalSessionReference] {
        guard let note = currentNote, note.isGlobal else { return [] }
        return SecondBrainEngine.scheduledSessions(forGlobalNoteID: note.id, blocks: store.blocks)
    }

    private var outgoingWikiLinks: [String] {
        let md = currentNote?.noteMarkdown ?? ""
        return SecondBrainEngine.extractWikiLinks(from: md)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()

            // 1. Subnotes section (child pages nested inside this parent note)
            if let parentNote = currentNote {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Label(
                            childSubnotes.isEmpty ? "Subnotas" : "Subnotas (\(childSubnotes.count))",
                            systemImage: "doc.on.doc"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isCreatingSubnote.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption2.weight(.bold))
                                Text("Subnota")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if isCreatingSubnote {
                        HStack(spacing: 8) {
                            TextField("Nome da nova subnota (ex.: SLO & Error Budget)…", text: $newSubnoteTitle)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { submitNewSubnote(parentNote: parentNote) }

                            Button("Criar") {
                                submitNewSubnote(parentNote: parentNote)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newSubnoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if !childSubnotes.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(childSubnotes) { child in
                                subnoteCard(child)
                            }
                        }
                    }
                }
            }

            // 2. Outgoing [[wikilinks]] chips
            if !outgoingWikiLinks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Citações nesta nota", systemImage: "link")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    FlowChipWrap(items: outgoingWikiLinks) { linkTitle in
                        Button {
                            viewModel.openOrCreateWikiLink(
                                title: linkTitle,
                                fromParentTitle: currentTitle,
                                fromParentNoteID: currentNote?.id,
                                in: store
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(linkTitle)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 3. Backlinks ("Mencionado em")
            if !backlinks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Mencionado em (\(backlinks.count))", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    ForEach(backlinks) { ref in
                        Button {
                            openBacklink(ref)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: ref.isGlobal ? "globe" : (ref.source.isAgenda ? "calendar" : "doc.text"))
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: ref.category?.colorHex ?? AppTheme.defaultAccentHex))
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(ref.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(AppTheme.shortDate(ref.date))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    if !ref.snippet.isEmpty {
                                        Text(ref.snippet)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.secondarySurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 4. Scheduled Sessions history for Global Blocks
            if !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(L10n.scheduledSessionsTitle) (\(sessions.count))", systemImage: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sessions) { sess in
                                Button {
                                    viewModel.jumpToAgendaBlock(sess.block)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: sess.isCompleted ? "checkmark.circle.fill" : "calendar")
                                            .font(.system(size: 10))
                                            .foregroundStyle(sess.isCompleted ? accentColor : .secondary)
                                        Text(AppTheme.shortDate(sess.date))
                                            .font(.caption2.weight(.semibold))
                                        if !sess.isAllDay {
                                            Text(TimelineMath.formatTimeRange(start: sess.startDate, end: sess.endDate))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.secondarySurface.opacity(0.8), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func subnoteCard(_ child: StandaloneNote) -> some View {
        let childColor = Color(hex: store.category(for: child.categoryID)?.colorHex ?? AppTheme.defaultAccentHex)
        let nestedCount = SecondBrainEngine.descendantCount(of: child.id, in: store.notes)
        let preview = child.summary(attachmentCount: store.attachments(forNoteID: child.id).count).previewText

        return Button {
            viewModel.openGlobalNoteInNotes(child)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: child.isGlobal ? "globe" : "doc.text.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(childColor)
                    .frame(width: 24, height: 24)
                    .background(childColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(child.title.isEmpty ? L10n.untitledNote : child.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if nestedCount > 0 {
                            Text("+\(nestedCount)")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppTheme.canvasBackground, in: Capsule())
                        }
                    }

                    if !preview.isEmpty {
                        Text(preview)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.secondarySurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(AppTheme.hairline.opacity(0.5), lineWidth: 0.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.openGlobalNoteInNotes(child)
            } label: {
                Label("Abrir subnota", systemImage: "doc.text")
            }

            #if os(macOS)
            Button {
                openWindow(id: DetachedEditorTarget.windowID, value: DetachedEditorTarget.standaloneNote(child.id))
            } label: {
                Label("Abrir em outra janela", systemImage: "arrow.up.forward.app")
            }
            #endif

            Button {
                _ = viewModel.createSubnote(title: "", parentNote: child, appendWikiLinkToParent: false, openCreated: true, in: store)
            } label: {
                Label("Nova subnota dentro desta", systemImage: "doc.badge.plus")
            }

            Button {
                viewModel.moveNote(child, toParentID: nil, in: store)
            } label: {
                Label("Mover para raiz", systemImage: "arrow.up.to.line")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteStandaloneNote(child, in: store)
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private func submitNewSubnote(parentNote: StandaloneNote) {
        let trimmed = newSubnoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = viewModel.createSubnote(
            title: trimmed,
            parentNote: parentNote,
            appendWikiLinkToParent: true,
            openCreated: true,
            in: store
        )
        newSubnoteTitle = ""
        isCreatingSubnote = false
    }

    private func openBacklink(_ ref: BacklinkReference) {
        switch ref.source {
        case .standaloneNote(let note):
            viewModel.openGlobalNoteInNotes(note)
        case .agendaBlock(let block):
            viewModel.jumpToAgendaBlock(block)
        }
    }
}

private extension BacklinkReference.SourceKind {
    var isAgenda: Bool {
        if case .agendaBlock = self { return true }
        return false
    }
}

/// Simple horizontal scrollable chip row for outgoing wikilinks.
private struct FlowChipWrap<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}
