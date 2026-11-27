import Foundation

/// A time block on a specific day containing a continuous rich note document.
/// Can be standalone (`seriesID == nil`) or a per-day override of a `RecurrenceSeries`.
public struct TimeBlock: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var isCompleted: Bool
    public var reminderMinutesBefore: Int?
    public var noteMarkdown: String
    public var plainTextIndex: String
    public var categoryID: UUID?
    public var seriesID: UUID?
    public var globalNoteID: UUID?
    public var routineItemID: UUID?
    public var occurrenceOriginalDate: Date?
    public var isDeletedOverride: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String = "",
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        isCompleted: Bool = false,
        reminderMinutesBefore: Int? = nil,
        noteMarkdown: String = "",
        categoryID: UUID? = nil,
        seriesID: UUID? = nil,
        globalNoteID: UUID? = nil,
        routineItemID: UUID? = nil,
        occurrenceOriginalDate: Date? = nil,
        isDeletedOverride: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = max(endDate, startDate.addingTimeInterval(15 * 60))
        self.isAllDay = isAllDay
        self.isCompleted = isCompleted
        self.reminderMinutesBefore = reminderMinutesBefore
        self.noteMarkdown = noteMarkdown
        self.plainTextIndex = RichNoteDocument.summarize(markdown: noteMarkdown).plainTextIndex
        self.categoryID = categoryID
        self.seriesID = seriesID
        self.globalNoteID = globalNoteID
        self.routineItemID = routineItemID
        self.occurrenceOriginalDate = occurrenceOriginalDate
        self.isDeletedOverride = isDeletedOverride
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public mutating func updateNoteMarkdown(_ markdown: String, attachmentCount: Int = 0) {
        self.noteMarkdown = markdown
        self.plainTextIndex = RichNoteDocument.summarize(
            markdown: markdown,
            attachmentCount: attachmentCount
        ).plainTextIndex
        self.updatedAt = Date()
    }

    public func summary(attachmentCount: Int = 0) -> RichNoteSummary {
        RichNoteDocument.summarize(markdown: noteMarkdown, attachmentCount: attachmentCount)
    }
}
