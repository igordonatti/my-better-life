import SwiftUI
import MyBetterLifeCore

/// Clean, full-height Markdown document inspector (macOS) / sheet (iOS) for the selected time block.
/// When linked to a Global Block, edits the single living Global document directly and displays
/// Second-Brain backlinks and scheduled sessions.
public struct BlockInspectorView: View {
    public let store: PlannerStore
    public let occurrence: DayOccurrence
    @Bindable public var viewModel: PlannerViewModel
    public let focusManager: FocusSessionManager?
    public let showCloseButton: Bool
    public let isDetachedWindow: Bool

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var titleDraft: String = ""
    @State private var templateSavedFeedback: Bool = false
    @FocusState private var isTitleFocused: Bool

    public init(
        store: PlannerStore,
        occurrence: DayOccurrence,
        viewModel: PlannerViewModel,
        focusManager: FocusSessionManager? = nil,
        showCloseButton: Bool = false,
        isDetachedWindow: Bool = false
    ) {
        self.store = store
        self.occurrence = occurrence
        self.viewModel = viewModel
        self.focusManager = focusManager
        self.showCloseButton = showCloseButton
        self.isDetachedWindow = isDetachedWindow
    }

    private var accentColor: Color {
        Color(hex: occurrence.category?.colorHex ?? AppTheme.defaultAccentHex)
    }

    private var currentAttachments: [BlockAttachment] {
        if let global = occurrence.globalNote {
            return store.attachments(forNoteID: global.id)
        }
        if let block = occurrence.block {
            return store.attachments(forBlockID: block.id)
        }
        if let series = occurrence.series {
            return store.attachments(forSeriesID: series.id)
        }
        return []
    }

    private var suggestedGlobalMatches: [StandaloneNote] {
        guard !occurrence.isGlobalLinked,
              !titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return SecondBrainEngine.suggestGlobalBlocks(matching: titleDraft, in: store.notes, limit: 3)
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                if let globalNote = occurrence.globalNote {
                    NoteBreadcrumbBar(
                        store: store,
                        viewModel: viewModel,
                        currentNote: globalNote,
                        accentColor: accentColor
                    )
                }
                headerRow
                globalContextBar
                recurringTemplateBar
                categoryStrip
                richNoteSection
                SecondBrainConnectionsView(
                    store: store,
                    viewModel: viewModel,
                    currentTitle: titleDraft,
                    currentNote: occurrence.globalNote,
                    currentBlockID: occurrence.block?.id,
                    accentColor: accentColor
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvasBackground)
        .onAppear {
            titleDraft = occurrence.title
            if viewModel.shouldFocusTitleField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTitleFocused = true
                    viewModel.shouldFocusTitleField = false
                }
            }
        }
        .onChange(of: occurrence.id) { _, _ in
            titleDraft = occurrence.title
            if viewModel.shouldFocusTitleField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTitleFocused = true
                    viewModel.shouldFocusTitleField = false
                }
            }
        }
        .onChange(of: occurrence.title) { _, newValue in
            if titleDraft != newValue && !isTitleFocused {
                titleDraft = newValue
            }
        }
    }

    // MARK: - Title & Actions Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                viewModel.toggleCompletion(for: occurrence, in: store)
            } label: {
                Image(systemName: occurrence.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(occurrence.isCompleted ? accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.markCompleted)

            TextField(L10n.titlePlaceholder, text: $titleDraft)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onChange(of: titleDraft) { _, newValue in
                    guard newValue != occurrence.title else { return }
                    viewModel.updateOccurrenceTitle(newValue, for: occurrence, in: store)
                }

            if let focusManager, !occurrence.isAllDay {
                let isFocusingThis = focusManager.isActive && focusManager.activeBlockID == occurrence.block?.id && occurrence.block != nil
                Menu {
                    Button {
                        focusManager.start(occurrence: occurrence, mode: .blockDuration, in: store)
                    } label: {
                        Label("Focar pelo tempo do bloco", systemImage: "timer")
                    }
                    Button {
                        focusManager.start(occurrence: occurrence, mode: .pomodoro(workMinutes: 25, breakMinutes: 5), in: store)
                    } label: {
                        Label("Pomodoro 25/5 min", systemImage: "flame")
                    }
                    if isFocusingThis {
                        Divider()
                        Button(role: .destructive) {
                            focusManager.stop()
                        } label: {
                            Label(L10n.stopFocus, systemImage: "stop.circle")
                        }
                    }
                } label: {
                    Image(systemName: isFocusingThis ? "timer.circle.fill" : "timer")
                        .font(.subheadline)
                        .foregroundStyle(isFocusingThis ? accentColor : .secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L10n.startFocus)
            }

            if !occurrence.isAllDay {
                let currentReminder = ReminderOption.from(minutesBefore: occurrence.reminderMinutesBefore)
                Menu {
                    ForEach(ReminderOption.allCases) { option in
                        Button {
                            viewModel.updateOccurrenceReminder(option.minutesBefore, for: occurrence, in: store)
                        } label: {
                            Label(
                                option.displayName,
                                systemImage: option == currentReminder ? "checkmark" : "bell"
                            )
                        }
                    }
                } label: {
                    Image(systemName: currentReminder == .none ? "bell.slash" : "bell.fill")
                        .font(.subheadline)
                        .foregroundStyle(currentReminder == .none ? Color.secondary : Color.orange)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(currentReminder == .none ? L10n.reminderNone : "\(L10n.reminder): \(currentReminder.displayName)")
            }

            #if os(macOS)
            if !isDetachedWindow {
                Button {
                    if let ref = viewModel.occurrenceRef(for: occurrence),
                       let target = DetachedEditorTarget(from: ref) {
                        openWindow(id: DetachedEditorTarget.windowID, value: target)
                        viewModel.closeTab(ref)
                    }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Destacar em nova janela (⌘⇧O)")
            }
            #endif

            Button {
                if occurrence.isGlobalLinked {
                    if let g = occurrence.globalNote {
                        viewModel.openGlobalNoteInNotes(g)
                    }
                } else {
                    viewModel.promoteToGlobalBlock(occurrence: occurrence, in: store)
                }
            } label: {
                Image(systemName: "globe")
                    .font(.subheadline)
                    .foregroundStyle(occurrence.isGlobalLinked ? accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(occurrence.isGlobalLinked ? "Bloco Global ativo (abrir em Notas)" : L10n.makeGlobalBlock)

            Button(role: .destructive) {
                viewModel.requestDelete(occurrence: occurrence, in: store)
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("\(L10n.deleteBlock) (⌫)")

            if showCloseButton {
                Button {
                    viewModel.clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Global Block Banner OR Smart Match Suggestions

    @ViewBuilder
    private var globalContextBar: some View {
        if let global = occurrence.globalNote {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.caption2.weight(.semibold))
                    Text("Bloco Global · Documento vivo compartilhado")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(accentColor)

                Spacer()

                Button("Ver em Notas") {
                    viewModel.openGlobalNoteInNotes(global)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)

                Button {
                    viewModel.unlinkFromGlobalBlock(occurrence: occurrence, in: store)
                } label: {
                    Image(systemName: "link.badge.plus")
                        .symbolRenderingMode(.hierarchical)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.unlinkGlobalBlock)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if !suggestedGlobalMatches.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Vincular a global:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(suggestedGlobalMatches) { global in
                        Button {
                            viewModel.linkOccurrence(occurrence, toGlobalNote: global, in: store)
                            titleDraft = global.title
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(global.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Recurring Series Template Bar

    @ViewBuilder
    private var recurringTemplateBar: some View {
        if let series = occurrence.series, !occurrence.isGlobalLinked {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "repeat")
                        .font(.caption2.weight(.semibold))
                    Text("Repete: \(series.ruleType.displayName)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.applyNoteAsSeriesTemplate(for: occurrence, in: store)
                    templateSavedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        templateSavedFeedback = false
                    }
                } label: {
                    Label(
                        templateSavedFeedback ? "Modelo salvo ✓" : "Usar notas como modelo dos próximos dias",
                        systemImage: templateSavedFeedback ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(templateSavedFeedback ? Color.green : accentColor)
                }
                .buttonStyle(.plain)
                .help("Aplica as notas e checklists deste dia como ponto de partida dos próximos dias da série")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Compact Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip(
                    title: L10n.noCategory,
                    symbol: "circle.dashed",
                    color: .secondary,
                    isSelected: occurrence.category == nil
                ) {
                    viewModel.updateOccurrenceCategory(nil, for: occurrence, in: store)
                }

                ForEach(store.categories) { category in
                    categoryChip(
                        title: category.name,
                        symbol: category.symbolName,
                        color: Color(hex: category.colorHex),
                        isSelected: occurrence.category?.id == category.id
                    ) {
                        viewModel.updateOccurrenceCategory(category.id, for: occurrence, in: store)
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
            .background(
                Capsule().fill(isSelected ? color : color.opacity(0.11))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Full-Height Live Markdown Canvas

    private var richNoteSection: some View {
        RichNoteEditorView(
            markdown: Binding(
                get: { occurrence.noteMarkdown },
                set: { newMarkdown in
                    viewModel.updateNoteMarkdown(newMarkdown, for: occurrence, in: store)
                }
            ),
            attachments: currentAttachments,
            accentColor: accentColor,
            availableWikiTargets: store.notes,
            excludingNoteID: occurrence.globalNote?.id,
            onToggleChecklistLine: { lineIndex in
                viewModel.toggleChecklistLine(at: lineIndex, for: occurrence, in: store)
            },
            onAttachImage: { data, fileName in
                viewModel.attachImage(rawData: data, fileName: fileName, to: occurrence, in: store)
            },
            onRemoveAttachment: { attachment in
                viewModel.removeAttachment(attachment, from: occurrence, in: store)
            },
            onOpenWikiLink: { targetTitle in
                viewModel.openOrCreateWikiLink(
                    title: targetTitle,
                    fromParentTitle: titleDraft,
                    fromParentNoteID: occurrence.globalNote?.id,
                    in: store
                )
            },
            onCreateSubnoteInline: occurrence.globalNote.map { globalParent in
                { newTitle in
                    _ = viewModel.createSubnote(
                        title: newTitle,
                        parentNote: globalParent,
                        appendWikiLinkToParent: false,
                        openCreated: false,
                        in: store
                    )
                }
            }
        )
    }
}
