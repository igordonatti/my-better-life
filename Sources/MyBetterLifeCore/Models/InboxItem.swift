import Foundation

/// A quick-capture task or idea stored in the Inbox without a scheduled time yet.
/// Can be dragged onto the Day Timeline to convert into a concrete `TimeBlock`.
public struct InboxItem: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var noteMarkdown: String
    public var estimatedMinutes: Int
    public var isCompleted: Bool
    public var categoryID: UUID?
    public var globalNoteID: UUID?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        noteMarkdown: String = "",
        estimatedMinutes: Int = 30,
        isCompleted: Bool = false,
        categoryID: UUID? = nil,
        globalNoteID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.noteMarkdown = noteMarkdown
        self.estimatedMinutes = max(15, estimatedMinutes)
        self.isCompleted = isCompleted
        self.categoryID = categoryID
        self.globalNoteID = globalNoteID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
