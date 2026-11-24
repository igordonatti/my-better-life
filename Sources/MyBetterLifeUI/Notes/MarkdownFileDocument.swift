import Foundation
import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    static let markdownDocument: UTType = UTType(filenameExtension: "md") ?? .plainText
}

/// Lightweight SwiftUI FileDocument used for exporting any note as a `.md` file.
public struct MarkdownFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    public static var writableContentTypes: [UTType] { [.markdownDocument, .plainText] }

    public var content: String

    public init(title: String, markdown: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            self.content = markdown
        } else if markdown.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# ") {
            self.content = markdown
        } else {
            self.content = "# \(trimmedTitle)\n\n\(markdown)"
        }
    }

    public init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let str = String(data: data, encoding: .utf8) {
            self.content = str
        } else {
            self.content = ""
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }

    public static func sanitizedFilename(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "nota" : trimmed
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = base.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.hasSuffix(".md") ? cleaned : "\(cleaned).md"
    }
}
