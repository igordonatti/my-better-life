import Foundation

/// Filter controlling which sources of `.md` notes appear in the Notes workspace.
public enum NoteOriginFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case globalOnly
    case standaloneOnly
    case agendaOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return L10n.notesFilterAll
        case .globalOnly: return L10n.notesFilterGlobal
        case .standaloneOnly: return L10n.notesFilterStandalone
        case .agendaOnly: return L10n.notesFilterAgenda
        }
    }
}

/// Unified `.md` note representation for the Notes library, combining
/// global hubs, standalone notes (quick notes / to-dos), and agenda blocks that contain notes.
public struct UnifiedNoteItem: Identifiable, Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case standalone(StandaloneNote)
        case agendaBlock(TimeBlock)
    }

    public let id: String
    public let source: Source
    public let title: String
    public let noteMarkdown: String
    public let isPinned: Bool
    public let isGlobal: Bool
    public let isFromAgenda: Bool
    public let referenceDate: Date
    public let updatedAt: Date
    public let category: BlockCategory?
    public let attachmentCount: Int

    public var summary: RichNoteSummary {
        RichNoteDocument.summarize(markdown: noteMarkdown, attachmentCount: attachmentCount)
    }

    public var standaloneNote: StandaloneNote? {
        if case .standalone(let note) = source { return note }
        return nil
    }

    public var agendaBlock: TimeBlock? {
        if case .agendaBlock(let block) = source { return block }
        return nil
    }
}

/// Filters, merges, and sorts standalone notes and non-empty agenda notes.
public enum NotesLibraryEngine {
    public static func items(
        notes: [StandaloneNote],
        blocks: [TimeBlock],
        categories: [BlockCategory],
        attachments: [BlockAttachment],
        originFilter: NoteOriginFilter = .all,
        filterDay: Date? = nil,
        categoryFilterID: UUID? = nil,
        searchQuery: String = "",
        calendar: Calendar = .current
    ) -> [UnifiedNoteItem] {
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let blockAttCount = Dictionary(grouping: attachments.compactMap(\.blockID), by: { $0 }).mapValues(\.count)
        let noteAttCount = Dictionary(grouping: attachments.compactMap(\.noteID), by: { $0 }).mapValues(\.count)

        let queryTokens = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        var result: [UnifiedNoteItem] = []

        // 1. Standalone notes & Global Blocks
        if originFilter == .all || originFilter == .standaloneOnly || originFilter == .globalOnly {
            for note in notes {
                if originFilter == .globalOnly && !note.isGlobal { continue }
                if originFilter == .standaloneOnly && note.isGlobal { continue }
                if let catID = categoryFilterID, note.categoryID != catID { continue }
                if let filterDay {
                    let matchesCreated = calendar.isDate(note.createdAt, inSameDayAs: filterDay)
                    let matchesUpdated = calendar.isDate(note.updatedAt, inSameDayAs: filterDay)
                    let matchesLinkedSession = note.isGlobal && blocks.contains(where: {
                        $0.globalNoteID == note.id && !$0.isDeletedOverride && calendar.isDate($0.startDate, inSameDayAs: filterDay)
                    })
                    if !matchesCreated && !matchesUpdated && !matchesLinkedSession { continue }
                }
                if !matchesQuery(tokens: queryTokens, title: note.title, plainText: note.plainTextIndex, markdown: note.noteMarkdown) {
                    continue
                }
                result.append(UnifiedNoteItem(
                    id: "note-\(note.id.uuidString)",
                    source: .standalone(note),
                    title: note.title,
                    noteMarkdown: note.noteMarkdown,
                    isPinned: note.isPinned,
                    isGlobal: note.isGlobal,
                    isFromAgenda: false,
                    referenceDate: note.updatedAt,
                    updatedAt: note.updatedAt,
                    category: note.categoryID.flatMap { categoryByID[$0] },
                    attachmentCount: noteAttCount[note.id] ?? 0
                ))
            }
        }

        // 2. Agenda blocks that contain written Markdown or image attachments (excluding blocks already linked to a Global Hub)
        if originFilter == .all || originFilter == .agendaOnly {
            for block in blocks where !block.isDeletedOverride && block.globalNoteID == nil {
                let attCount = blockAttCount[block.id] ?? 0
                let hasContent = !block.noteMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attCount > 0
                guard hasContent else { continue }

                if let catID = categoryFilterID, block.categoryID != catID { continue }
                if let filterDay, !calendar.isDate(block.startDate, inSameDayAs: filterDay) {
                    continue
                }
                if !matchesQuery(tokens: queryTokens, title: block.title, plainText: block.plainTextIndex, markdown: block.noteMarkdown) {
                    continue
                }
                result.append(UnifiedNoteItem(
                    id: "agenda-\(block.id.uuidString)",
                    source: .agendaBlock(block),
                    title: block.title,
                    noteMarkdown: block.noteMarkdown,
                    isPinned: false,
                    isGlobal: false,
                    isFromAgenda: true,
                    referenceDate: block.startDate,
                    updatedAt: block.updatedAt,
                    category: block.categoryID.flatMap { categoryByID[$0] },
                    attachmentCount: attCount
                ))
            }
        }

        // Sort: Pinned first, then Global Hubs, then most recently updated descending
        return result.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func matchesQuery(
        tokens: [String],
        title: String,
        plainText: String,
        markdown: String
    ) -> Bool {
        guard !tokens.isEmpty else { return true }
        let titleFolded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let body = plainText.isEmpty ? RichNoteDocument.summarize(markdown: markdown).plainTextIndex : plainText
        let bodyFolded = body.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let combined = titleFolded + " " + bodyFolded
        return tokens.allSatisfy { combined.contains($0) }
    }
}
