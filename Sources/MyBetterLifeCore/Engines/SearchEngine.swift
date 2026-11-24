import Foundation

/// A single global search hit pointing to a concrete block, recurring routine, or standalone note.
public struct GlobalSearchResult: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let snippet: String
    public let targetDate: Date
    public let isRecurringTemplate: Bool
    public let category: BlockCategory?
    public let block: TimeBlock?
    public let series: RecurrenceSeries?
    public let note: StandaloneNote?

    public init(
        id: String,
        title: String,
        snippet: String,
        targetDate: Date,
        isRecurringTemplate: Bool,
        category: BlockCategory?,
        block: TimeBlock?,
        series: RecurrenceSeries?,
        note: StandaloneNote? = nil
    ) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.targetDate = targetDate
        self.isRecurringTemplate = isRecurringTemplate
        self.category = category
        self.block = block
        self.series = series
        self.note = note
    }
}

/// Instant global search across block titles, standalone notes, extracted note plain text, and recurring series templates.
public enum SearchEngine {
    public static func search(
        query: String,
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote] = [],
        categories: [BlockCategory] = [],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [GlobalSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokens = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !tokens.isEmpty else { return [] }

        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let seriesByID = Dictionary(uniqueKeysWithValues: seriesList.map { ($0.id, $0) })
        var results: [GlobalSearchResult] = []

        // 1. Concrete blocks (standalone + per-day overrides)
        for block in blocks where !block.isDeletedOverride {
            let titleFolded = block.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let noteText = block.plainTextIndex.isEmpty
                ? RichNoteDocument.summarize(markdown: block.noteMarkdown).plainTextIndex
                : block.plainTextIndex
            let noteFolded = noteText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let combined = titleFolded + " " + noteFolded

            if tokens.allSatisfy({ combined.contains($0) }) {
                let snippet = makeSnippet(from: noteText, matching: trimmed)
                results.append(GlobalSearchResult(
                    id: "block-\(block.id.uuidString)",
                    title: block.title.isEmpty ? L10n.untitledBlock : block.title,
                    snippet: snippet,
                    targetDate: calendar.startOfDay(for: block.startDate),
                    isRecurringTemplate: false,
                    category: block.categoryID.flatMap { categoryByID[$0] },
                    block: block,
                    series: block.seriesID.flatMap { seriesByID[$0] }
                ))
            }
        }

        // 2. Recurring series templates
        for series in seriesList {
            let titleFolded = series.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let noteText = series.templatePlainText.isEmpty
                ? RichNoteDocument.summarize(markdown: series.templateMarkdown).plainTextIndex
                : series.templatePlainText
            let noteFolded = noteText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let combined = titleFolded + " " + noteFolded

            if tokens.allSatisfy({ combined.contains($0) }) {
                let snippet = makeSnippet(from: noteText, matching: trimmed)
                let jumpDate = nextOccurrenceDate(for: series, from: referenceDate, calendar: calendar)
                    ?? calendar.startOfDay(for: series.seriesStartDate)
                results.append(GlobalSearchResult(
                    id: "series-\(series.id.uuidString)",
                    title: series.title.isEmpty ? L10n.untitledBlock : series.title,
                    snippet: snippet,
                    targetDate: jumpDate,
                    isRecurringTemplate: true,
                    category: series.categoryID.flatMap { categoryByID[$0] },
                    block: nil,
                    series: series
                ))
            }
        }

        // 3. Standalone Markdown notes
        for note in notes {
            let titleFolded = note.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let noteText = note.plainTextIndex.isEmpty
                ? RichNoteDocument.summarize(markdown: note.noteMarkdown).plainTextIndex
                : note.plainTextIndex
            let noteFolded = noteText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let combined = titleFolded + " " + noteFolded

            if tokens.allSatisfy({ combined.contains($0) }) {
                let snippet = makeSnippet(from: noteText, matching: trimmed)
                results.append(GlobalSearchResult(
                    id: "note-\(note.id.uuidString)",
                    title: note.title.isEmpty ? L10n.untitledNote : note.title,
                    snippet: snippet,
                    targetDate: calendar.startOfDay(for: note.updatedAt),
                    isRecurringTemplate: false,
                    category: note.categoryID.flatMap { categoryByID[$0] },
                    block: nil,
                    series: nil,
                    note: note
                ))
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.targetDate != rhs.targetDate {
                return lhs.targetDate > rhs.targetDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func makeSnippet(from text: String, matching query: String) -> String {
        guard !text.isEmpty else { return "" }
        if let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let windowStart = text.index(text.startIndex, offsetBy: max(0, startOffset - 28))
            let windowEnd = text.index(windowStart, offsetBy: min(110, text.distance(from: windowStart, to: text.endIndex)))
            let prefix = windowStart > text.startIndex ? "…" : ""
            let suffix = windowEnd < text.endIndex ? "…" : ""
            return prefix + String(text[windowStart..<windowEnd]).trimmingCharacters(in: .whitespacesAndNewlines) + suffix
        }
        return String(text.prefix(110))
    }

    private static func nextOccurrenceDate(
        for series: RecurrenceSeries,
        from referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        let start = max(calendar.startOfDay(for: referenceDate), calendar.startOfDay(for: series.seriesStartDate))
        for offset in 0..<35 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if RecurrenceEngine.seriesOccurs(series, on: candidate, calendar: calendar) {
                return candidate
            }
        }
        return nil
    }
}
