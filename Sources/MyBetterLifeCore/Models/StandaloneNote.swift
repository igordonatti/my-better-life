import Foundation

/// A standalone Markdown note (quick note, to-do list, or long-form document)
/// outside the timed agenda. CloudKit-ready value model.
public struct StandaloneNote: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var noteMarkdown: String
    public var plainTextIndex: String
    public var isPinned: Bool
    public var isGlobal: Bool
    public var categoryID: UUID?
    public var parentNoteID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String = "",
        noteMarkdown: String = "",
        isPinned: Bool = false,
        isGlobal: Bool = false,
        categoryID: UUID? = nil,
        parentNoteID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.noteMarkdown = noteMarkdown
        self.plainTextIndex = RichNoteDocument.summarize(markdown: noteMarkdown).plainTextIndex
        self.isPinned = isPinned
        self.isGlobal = isGlobal
        self.categoryID = categoryID
        self.parentNoteID = parentNoteID
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
