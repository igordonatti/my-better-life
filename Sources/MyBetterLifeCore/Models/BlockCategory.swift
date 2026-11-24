import Foundation

/// Customizable category with color and SF Symbol icon (CloudKit-ready schema).
public struct BlockCategory: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var symbolName: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        symbolName: String = "circle.fill",
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public static let curatedPalette: [String] = [
        "#3B82F6", // Azul
        "#10B981", // Esmeralda
        "#F59E0B", // Âmbar
        "#8B5CF6", // Violeta
        "#EF4444", // Coral
        "#EC4899", // Rosa
        "#06B6D4", // Ciano
        "#6366F1", // Índigo
        "#84CC16", // Lima
        "#64748B"  // Ardósia
    ]

    public static let curatedSymbols: [String] = [
        "briefcase.fill",
        "heart.fill",
        "person.fill",
        "book.fill",
        "sparkles",
        "figure.run",
        "brain.head.profile",
        "laptopcomputer",
        "house.fill",
        "star.fill",
        "bolt.fill",
        "leaf.fill",
        "music.note",
        "cart.fill",
        "cup.and.saucer.fill",
        "paintbrush.fill"
    ]
}
