import Foundation

/// Parsed elements of a continuous Apple Notes / Markdown note inside a time block.
public enum RichNoteLine: Identifiable, Equatable, Sendable {
    case heading(id: Int, level: Int, text: String)
    case checklist(id: Int, isChecked: Bool, text: String)
    case bullet(id: Int, text: String)
    case image(id: Int, attachmentID: UUID, caption: String)
    case paragraph(id: Int, text: String)
    case empty(id: Int)

    public var id: Int {
        switch self {
        case .heading(let id, _, _),
             .checklist(let id, _, _),
             .bullet(let id, _),
             .image(let id, _, _),
             .paragraph(let id, _),
             .empty(let id):
            return id
        }
    }
}

public struct ChecklistStats: Equatable, Sendable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }

    public var hasItems: Bool { total > 0 }
    public var isAllCompleted: Bool { total > 0 && completed == total }
}

public struct ExtractedLink: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let url: URL

    public init(title: String, url: URL) {
        self.id = "\(title)|\(url.absoluteString)"
        self.title = title
        self.url = url
    }
}

public struct RichNoteSummary: Equatable, Sendable {
    public let checklist: ChecklistStats
    public let previewText: String
    public let linkCount: Int
    public let imageCount: Int
    public let plainTextIndex: String
}

/// Stateless parser and mutator for continuous Markdown-backed rich notes.
public enum RichNoteDocument {
    public static let attachmentScheme = "attachment://"

    /// Parses markdown text into renderable continuous lines.
    public static func parseLines(from markdown: String) -> [RichNoteLine] {
        guard !markdown.isEmpty else { return [] }
        let rawLines = markdown.components(separatedBy: .newlines)
        var result: [RichNoteLine] = []
        result.reserveCapacity(rawLines.count)

        for (index, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(.empty(id: index))
                continue
            }

            // Inline image token: ![caption](attachment://<UUID>)
            if let (uuid, caption) = parseAttachmentImageLine(trimmed) {
                result.append(.image(id: index, attachmentID: uuid, caption: caption))
                continue
            }

            // Checklist item: - [ ] or - [x] / - [X] / * [ ]
            if let (checked, body) = parseChecklistLine(trimmed) {
                result.append(.checklist(id: index, isChecked: checked, text: body))
                continue
            }

            // Heading: #, ##, ###
            if let (level, body) = parseHeadingLine(trimmed) {
                result.append(.heading(id: index, level: level, text: body))
                continue
            }

            // Bullet item: - text or * text
            if let body = parseBulletLine(trimmed) {
                result.append(.bullet(id: index, text: body))
                continue
            }

            result.append(.paragraph(id: index, text: rawLine))
        }

        return result
    }

    /// Toggles the checkbox state on a specific line index and returns updated markdown.
    public static func toggleChecklist(at lineIndex: Int, in markdown: String) -> String {
        var rawLines = markdown.components(separatedBy: .newlines)
        guard lineIndex >= 0 && lineIndex < rawLines.count else { return markdown }

        let line = rawLines[lineIndex]
        let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let trimmed = String(line.dropFirst(leadingWhitespace.count))

        if let (isChecked, body) = parseChecklistLine(trimmed) {
            let marker = isChecked ? "- [ ] " : "- [x] "
            rawLines[lineIndex] = leadingWhitespace + marker + body
            return rawLines.joined(separator: "\n")
        }
        return markdown
    }

    /// Appends a markdown image reference for a stored BlockAttachment UUID.
    public static func appendImageReference(attachmentID: UUID, caption: String = "", to markdown: String) -> String {
        let token = "![\(caption)](\(attachmentScheme)\(attachmentID.uuidString))"
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return token + "\n"
        }
        let separator = markdown.hasSuffix("\n") ? "\n" : "\n\n"
        return markdown + separator + token + "\n"
    }

    /// Removes any inline image references matching the given attachment UUID.
    public static func removeImageReference(attachmentID: UUID, from markdown: String) -> String {
        let target = "\(attachmentScheme)\(attachmentID.uuidString)"
        let lines = markdown.components(separatedBy: .newlines)
        let filtered = lines.filter { !$0.localizedCaseInsensitiveContains(target) }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    /// Computes checklist stats, preview text, link/image counts, and searchable plain text.
    public static func summarize(markdown: String, attachmentCount: Int = 0) -> RichNoteSummary {
        let lines = parseLines(from: markdown)
        var completed = 0
        var total = 0
        var inlineImages = 0
        var preview = ""
        var plainParts: [String] = []

        for line in lines {
            switch line {
            case .heading(_, _, let text):
                let clean = stripInlineMarkdown(text)
                if preview.isEmpty && !clean.isEmpty { preview = clean }
                if !clean.isEmpty { plainParts.append(clean) }
            case .checklist(_, let isChecked, let text):
                total += 1
                if isChecked { completed += 1 }
                let clean = stripInlineMarkdown(text)
                if preview.isEmpty && !clean.isEmpty { preview = clean }
                if !clean.isEmpty { plainParts.append(clean) }
            case .bullet(_, let text):
                let clean = stripInlineMarkdown(text)
                if preview.isEmpty && !clean.isEmpty { preview = clean }
                if !clean.isEmpty { plainParts.append(clean) }
            case .paragraph(_, let text):
                let clean = stripInlineMarkdown(text)
                if preview.isEmpty && !clean.isEmpty { preview = clean }
                if !clean.isEmpty { plainParts.append(clean) }
            case .image(_, _, let caption):
                inlineImages += 1
                if !caption.isEmpty { plainParts.append(caption) }
            case .empty:
                break
            }
        }

        let links = extractLinks(from: markdown)
        return RichNoteSummary(
            checklist: ChecklistStats(completed: completed, total: total),
            previewText: preview,
            linkCount: links.count,
            imageCount: max(inlineImages, attachmentCount),
            plainTextIndex: plainParts.joined(separator: " ")
        )
    }

    /// Extracts both Markdown `[title](https://...)` links and raw `http(s)://...` URLs.
    public static func extractLinks(from markdown: String) -> [ExtractedLink] {
        var found: [ExtractedLink] = []
        var seenURLs = Set<String>()

        // 1. Markdown links [label](https://...) excluding images ![...](...)
        let mdPattern = #"(?<!!)\[([^\]]+)\]\((https?://[^\s\)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: mdPattern, options: [.caseInsensitive]) {
            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            for match in regex.matches(in: markdown, options: [], range: range) {
                guard let labelRange = Range(match.range(at: 1), in: markdown),
                      let urlRange = Range(match.range(at: 2), in: markdown) else { continue }
                let label = String(markdown[labelRange]).trimmingCharacters(in: .whitespaces)
                let urlString = String(markdown[urlRange])
                if let url = URL(string: urlString), !seenURLs.contains(urlString) {
                    seenURLs.insert(urlString)
                    found.append(ExtractedLink(title: label.isEmpty ? (url.host ?? urlString) : label, url: url))
                }
            }
        }

        // 2. Bare URLs
        let barePattern = #"(?<![\(\"])(https?://[^\s\)\]\>]+)"#
        if let regex = try? NSRegularExpression(pattern: barePattern, options: [.caseInsensitive]) {
            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            for match in regex.matches(in: markdown, options: [], range: range) {
                guard let urlRange = Range(match.range(at: 1), in: markdown) else { continue }
                var urlString = String(markdown[urlRange])
                while let last = urlString.last, [".", ",", ";", ":", ")"].contains(String(last)) {
                    urlString.removeLast()
                }
                if let url = URL(string: urlString), !seenURLs.contains(urlString) {
                    seenURLs.insert(urlString)
                    let display = url.host ?? urlString
                    found.append(ExtractedLink(title: display, url: url))
                }
            }
        }

        return found
    }

    /// Strips basic Markdown markers for clean search indexing & timeline previews.
    public static func stripInlineMarkdown(_ text: String) -> String {
        var output = text
        // Replace [label](url) with label
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "$1")
        }
        output = output
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "~~", with: "")
            .replacingOccurrences(of: "`", with: "")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Line Parsers

    private static func parseAttachmentImageLine(_ trimmed: String) -> (UUID, String)? {
        guard trimmed.hasPrefix("!["),
              let closeBracket = trimmed.range(of: "]("),
              trimmed.hasSuffix(")") else {
            return nil
        }
        let caption = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<closeBracket.lowerBound])
        let urlPart = String(trimmed[closeBracket.upperBound..<trimmed.index(before: trimmed.endIndex)])
        guard urlPart.lowercased().hasPrefix(attachmentScheme) else { return nil }
        let uuidString = String(urlPart.dropFirst(attachmentScheme.count))
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        return (uuid, caption)
    }

    private static func parseChecklistLine(_ trimmed: String) -> (Bool, String)? {
        let prefixes: [(String, Bool)] = [
            ("- [ ] ", false),
            ("- [x] ", true),
            ("- [X] ", true),
            ("* [ ] ", false),
            ("* [x] ", true),
            ("* [X] ", true),
            ("- [ ]", false),
            ("- [x]", true),
            ("- [X]", true)
        ]
        for (prefix, checked) in prefixes {
            if trimmed.hasPrefix(prefix) {
                let body = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return (checked, body)
            }
        }
        return nil
    }

    private static func parseHeadingLine(_ trimmed: String) -> (Int, String)? {
        if trimmed.hasPrefix("### ") {
            return (3, String(trimmed.dropFirst(4)))
        } else if trimmed.hasPrefix("## ") {
            return (2, String(trimmed.dropFirst(3)))
        } else if trimmed.hasPrefix("# ") {
            return (1, String(trimmed.dropFirst(2)))
        }
        return nil
    }

    private static func parseBulletLine(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("• ") {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }
}
