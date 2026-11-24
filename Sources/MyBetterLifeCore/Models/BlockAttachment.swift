import Foundation

/// External-storage image attachment linked to a `TimeBlock`, `RecurrenceSeries`, or `StandaloneNote`.
/// Persisted in Core Data with `allowsExternalBinaryDataStorage = true` so CloudKit syncs cleanly as CKAsset.
public struct BlockAttachment: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var fileName: String
    public var mimeType: String
    public var imageData: Data
    public var blockID: UUID?
    public var seriesID: UUID?
    public var noteID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        fileName: String = "imagem.png",
        mimeType: String = "image/png",
        imageData: Data,
        blockID: UUID? = nil,
        seriesID: UUID? = nil,
        noteID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.imageData = imageData
        self.blockID = blockID
        self.seriesID = seriesID
        self.noteID = noteID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
