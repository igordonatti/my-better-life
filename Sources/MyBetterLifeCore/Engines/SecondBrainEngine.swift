import Foundation

/// A backlink entry pointing from another note or agenda block that cites `[[Title]]`.
public struct BacklinkReference: Identifiable, Equatable, Sendable {
    public enum SourceKind: Equatable, Sendable {
        case standaloneNote(StandaloneNote)
        case agendaBlock(TimeBlock)
    }

    public let id: String
    public let source: SourceKind
    public let title: String
    public let snippet: String
    public let date: Date
    public let isGlobal: Bool
    public let category: BlockCategory?
}

/// A scheduled session on the Agenda linked to a Global Block.
public struct GlobalSessionReference: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let isCompleted: Bool
    public let block: TimeBlock
}

/// Second-Brain knowledge graph helpers: `[[wikilink]]` parsing, backlink resolution,
/// active `[[` autocomplete query detection, and scheduled session history for Global Blocks.
public enum SecondBrainEngine {
    /// Extracts all unique `[[Target Title]]` wiki-link targets from Markdown text.
    public static func extractWikiLinks(from markdown: String) -> [String] {
        let pattern = #"\[\[([^\]\n]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        var seen = Set<String>()
        var results: [String] = []
        for match in regex.matches(in: markdown, range: range) {
            guard let r = Range(match.range(at: 1), in: markdown) else { continue }
            let raw = String(markdown[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizeKey(raw)
            if !raw.isEmpty && !seen.contains(key) {
                seen.insert(key)
                results.append(raw)
            }
        }
        return results
    }

    /// Detects if the user is currently typing an unclosed `[[query` OR an inline `@query`
    /// citation at the end of the document (ignoring email addresses like `user@domain.com`).
    public static func activeWikiLinkQuery(in markdown: String) -> String? {
        if let openRange = markdown.range(of: "[[", options: .backwards) {
            let tail = String(markdown[openRange.upperBound...])
            if !tail.contains("]]") && !tail.contains("\n") {
                return tail
            }
        }

        // Check for trailing `@query` (must be at start of string or preceded by whitespace / list / paren)
        if let atRange = markdown.range(of: "@", options: .backwards) {
            let tail = String(markdown[atRange.upperBound...])
            if !tail.contains("\n") && !tail.contains("]]") && tail.count <= 48 {
                let isBoundaryBefore: Bool
                if atRange.lowerBound == markdown.startIndex {
                    isBoundaryBefore = true
                } else {
                    let prevChar = markdown[markdown.index(before: atRange.lowerBound)]
                    isBoundaryBefore = prevChar.isWhitespace || prevChar == "(" || prevChar == "[" || prevChar == "-" || prevChar == "*"
                }
                // Avoid triggering on emails (no dot right after word without spaces) or finished sentences
                if isBoundaryBefore && !tail.contains(".com") && !tail.contains(".br") && !tail.contains(".org") {
                    return tail
                }
            }
        }
        return nil
    }

    /// Completes the trailing unclosed `[[query` or `@query` with `[[targetTitle]] `.
    public static func completeTrailingWikiLink(in markdown: String, with targetTitle: String) -> String {
        if let openRange = markdown.range(of: "[[", options: .backwards) {
            let tail = String(markdown[openRange.upperBound...])
            if !tail.contains("]]") && !tail.contains("\n") {
                let prefix = String(markdown[..<openRange.lowerBound])
                return prefix + "[[\(targetTitle)]] "
            }
        }
        if let atRange = markdown.range(of: "@", options: .backwards) {
            let tail = String(markdown[atRange.upperBound...])
            if !tail.contains("\n") {
                let prefix = String(markdown[..<atRange.lowerBound])
                return prefix + "[[\(targetTitle)]] "
            }
        }
        return markdown + "[[\(targetTitle)]] "
    }

    // MARK: - Parent-Child Note Hierarchy (Notion-style Multi-level Subnotes)

    /// Direct child notes of `parentID`, sorted pinned first then most recently updated.
    public static func childNotes(of parentID: UUID, in notes: [StandaloneNote]) -> [StandaloneNote] {
        notes
            .filter { $0.parentNoteID == parentID }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    /// Returns the ordered ancestor chain from root down to the immediate parent of `note`
    /// (excluding `note` itself), with built-in cycle protection.
    public static func ancestorPath(for note: StandaloneNote, in notes: [StandaloneNote]) -> [StandaloneNote] {
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        var chain: [StandaloneNote] = []
        var visited: Set<UUID> = [note.id]
        var cursorParentID = note.parentNoteID

        while let pid = cursorParentID, !visited.contains(pid), let parent = byID[pid] {
            visited.insert(pid)
            chain.append(parent)
            cursorParentID = parent.parentNoteID
        }
        return chain.reversed()
    }

    /// Returns `true` if `noteID` can safely be moved under `newParentID` without creating a cycle.
    public static func canReparent(
        noteID: UUID,
        toParentID newParentID: UUID?,
        in notes: [StandaloneNote]
    ) -> Bool {
        guard let targetParentID = newParentID else { return true }
        if targetParentID == noteID { return false }

        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        var visited: Set<UUID> = []
        var cursor: UUID? = targetParentID
        while let currentID = cursor, !visited.contains(currentID) {
            if currentID == noteID { return false }
            visited.insert(currentID)
            cursor = byID[currentID]?.parentNoteID
        }
        return true
    }

    /// Counts all nested descendants (children, grandchildren, ...) under `noteID`.
    public static func descendantCount(of noteID: UUID, in notes: [StandaloneNote]) -> Int {
        let childrenByParent = Dictionary(grouping: notes.filter { $0.parentNoteID != nil }, by: { $0.parentNoteID! })
        var visited: Set<UUID> = [noteID]
        var queue: [UUID] = [noteID]
        var count = 0

        while !queue.isEmpty {
            let current = queue.removeFirst()
            for child in childrenByParent[current] ?? [] where !visited.contains(child.id) {
                visited.insert(child.id)
                count += 1
                queue.append(child.id)
            }
        }
        return count
    }

    /// Finds all standalone notes and agenda blocks that mention `[[targetTitle]]`.
    public static func backlinks(
        forTitle targetTitle: String,
        excludingNoteID: UUID? = nil,
        excludingBlockID: UUID? = nil,
        notes: [StandaloneNote],
        blocks: [TimeBlock],
        categories: [BlockCategory]
    ) -> [BacklinkReference] {
        let targetKey = normalizeKey(targetTitle)
        guard !targetKey.isEmpty else { return [] }

        let catByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var refs: [BacklinkReference] = []

        for note in notes where note.id != excludingNoteID {
            let links = extractWikiLinks(from: note.noteMarkdown)
            if links.contains(where: { normalizeKey($0) == targetKey }) {
                refs.append(BacklinkReference(
                    id: "bl-note-\(note.id.uuidString)",
                    source: .standaloneNote(note),
                    title: note.title.isEmpty ? L10n.untitledNote : note.title,
                    snippet: extractContextSnippet(around: targetTitle, in: note.noteMarkdown),
                    date: note.updatedAt,
                    isGlobal: note.isGlobal,
                    category: note.categoryID.flatMap { catByID[$0] }
                ))
            }
        }

        for block in blocks where block.id != excludingBlockID && !block.isDeletedOverride && block.globalNoteID == nil {
            let links = extractWikiLinks(from: block.noteMarkdown)
            if links.contains(where: { normalizeKey($0) == targetKey }) {
                refs.append(BacklinkReference(
                    id: "bl-block-\(block.id.uuidString)",
                    source: .agendaBlock(block),
                    title: block.title.isEmpty ? L10n.untitledBlock : block.title,
                    snippet: extractContextSnippet(around: targetTitle, in: block.noteMarkdown),
                    date: block.startDate,
                    isGlobal: false,
                    category: block.categoryID.flatMap { catByID[$0] }
                ))
            }
        }

        return refs.sorted { $0.date > $1.date }
    }

    /// Returns all concrete agenda sessions linked to a Global Block, newest first.
    public static func scheduledSessions(
        forGlobalNoteID globalNoteID: UUID,
        blocks: [TimeBlock]
    ) -> [GlobalSessionReference] {
        blocks
            .filter { $0.globalNoteID == globalNoteID && !$0.isDeletedOverride }
            .sorted { $0.startDate > $1.startDate }
            .map { block in
                GlobalSessionReference(
                    id: "sess-\(block.id.uuidString)",
                    date: Calendar.current.startOfDay(for: block.startDate),
                    startDate: block.startDate,
                    endDate: block.endDate,
                    isAllDay: block.isAllDay,
                    isCompleted: block.isCompleted,
                    block: block
                )
            }
    }

    /// Suggests matching Global Blocks when typing a title or query.
    public static func suggestGlobalBlocks(
        matching query: String,
        in notes: [StandaloneNote],
        limit: Int = 5
    ) -> [StandaloneNote] {
        let globals = notes.filter { $0.isGlobal }
        let cleaned = normalizeKey(query)
        guard !cleaned.isEmpty else {
            return Array(globals.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
        }
        return Array(
            globals
                .filter { normalizeKey($0.title).contains(cleaned) }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(limit)
        )
    }

    /// Suggests all notes (prioritizing Global Blocks) for `[[` autocomplete.
    public static func suggestWikiTargets(
        matching query: String,
        in notes: [StandaloneNote],
        excludingNoteID: UUID? = nil,
        limit: Int = 6
    ) -> [StandaloneNote] {
        let cleaned = normalizeKey(query)
        let pool = notes.filter { $0.id != excludingNoteID && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        let filtered = cleaned.isEmpty
            ? pool
            : pool.filter { normalizeKey($0.title).contains(cleaned) }

        return Array(
            filtered.sorted { lhs, rhs in
                if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal }
                return lhs.updatedAt > rhs.updatedAt
            }.prefix(limit)
        )
    }

    public static func normalizeKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func extractContextSnippet(around target: String, in markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        let needle = "[[\(target)]]"
        if let matchingLine = lines.first(where: { $0.localizedCaseInsensitiveContains(needle) }) {
            return RichNoteDocument.stripInlineMarkdown(matchingLine)
        }
        return RichNoteDocument.summarize(markdown: markdown).previewText
    }
}
