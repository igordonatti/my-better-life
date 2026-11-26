import Foundation

/// Pure, testable Markdown text-transformation engine used by note editor formatting
/// shortcuts (`⌘B`/`⌃B`, `⌘I`/`⌃I`, `⌘⇧X`, `⌘\``, `⌘L`, `⌘⇧8`, `⌘⇧H`, `⌘⇧K`, `⌘↩`)
/// and the Markdown formatting toolbar.
public enum MarkdownFormatAction: Equatable, Sendable {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case heading(level: Int?) // nil = cycle ## -> ### -> # -> none
    case checklist
    case toggleChecklistCheck
    case bulletList
    case link
}

public struct MarkdownEditResult: Equatable, Sendable {
    /// Range in the original UTF-16 `NSString` that should be replaced.
    public let replaceRange: NSRange
    /// Replacement text to insert into `replaceRange`.
    public let replacement: String
    /// Resulting cursor/selection range in the updated UTF-16 `NSString`.
    public let newSelection: NSRange

    public init(replaceRange: NSRange, replacement: String, newSelection: NSRange) {
        self.replaceRange = replaceRange
        self.replacement = replacement
        self.newSelection = newSelection
    }
}

public enum MarkdownFormattingEngine {

    public static func apply(
        _ action: MarkdownFormatAction,
        to text: String,
        selection: NSRange
    ) -> MarkdownEditResult {
        let ns = text as NSString
        let clampedLoc = max(0, min(selection.location, ns.length))
        let clampedLen = max(0, min(selection.length, ns.length - clampedLoc))
        let safeSelection = NSRange(location: clampedLoc, length: clampedLen)

        switch action {
        case .bold:
            return toggleInlineWrapper("**", in: ns, selection: safeSelection)
        case .italic:
            return toggleInlineWrapper("*", in: ns, selection: safeSelection, avoidDoubledMarker: true)
        case .strikethrough:
            return toggleInlineWrapper("~~", in: ns, selection: safeSelection)
        case .inlineCode:
            return toggleInlineWrapper("`", in: ns, selection: safeSelection)
        case .heading(let level):
            return toggleHeading(level: level, in: ns, selection: safeSelection)
        case .checklist:
            return toggleLinePrefix("- [ ] ", clearingPrefixes: ["- [x] ", "- [X] ", "- ", "* "], in: ns, selection: safeSelection)
        case .toggleChecklistCheck:
            return toggleChecklistState(in: ns, selection: safeSelection)
        case .bulletList:
            return toggleLinePrefix("- ", clearingPrefixes: ["- [ ] ", "- [x] ", "- [X] ", "* "], in: ns, selection: safeSelection)
        case .link:
            return insertMarkdownLink(in: ns, selection: safeSelection)
        }
    }

    // MARK: - Inline Wrappers (**bold**, *italic*, ~~strike~~, `code`)

    private static func toggleInlineWrapper(
        _ marker: String,
        in ns: NSString,
        selection: NSRange,
        avoidDoubledMarker: Bool = false
    ) -> MarkdownEditResult {
        let mLen = (marker as NSString).length

        // 1. Check if selection itself starts and ends with the marker
        if selection.length >= mLen * 2 {
            let selectedText = ns.substring(with: selection)
            let isWrappedInside = selectedText.hasPrefix(marker) && selectedText.hasSuffix(marker) &&
                (!avoidDoubledMarker || !(selectedText.hasPrefix("**") && selectedText.hasSuffix("**")))
            if isWrappedInside {
                let innerRange = NSRange(location: selection.location + mLen, length: selection.length - mLen * 2)
                let inner = ns.substring(with: innerRange)
                return MarkdownEditResult(
                    replaceRange: selection,
                    replacement: inner,
                    newSelection: NSRange(location: selection.location, length: (inner as NSString).length)
                )
            }
        }

        // 2. Check if the characters immediately surrounding selection are the marker
        if selection.location >= mLen && NSMaxRange(selection) + mLen <= ns.length {
            let beforeRange = NSRange(location: selection.location - mLen, length: mLen)
            let afterRange = NSRange(location: NSMaxRange(selection), length: mLen)
            let before = ns.substring(with: beforeRange)
            let after = ns.substring(with: afterRange)

            var matchesSurrounding = (before == marker && after == marker)
            if matchesSurrounding && avoidDoubledMarker {
                // Make sure surrounding `*` isn't actually part of `**`
                let hasExtraBefore = selection.location >= 2 && ns.substring(with: NSRange(location: selection.location - 2, length: 2)) == "**"
                let hasExtraAfter = NSMaxRange(selection) + 2 <= ns.length && ns.substring(with: NSRange(location: NSMaxRange(selection), length: 2)) == "**"
                if hasExtraBefore && hasExtraAfter {
                    matchesSurrounding = false
                }
            }

            if matchesSurrounding {
                let inner = ns.substring(with: selection)
                let expandedRange = NSRange(location: selection.location - mLen, length: selection.length + mLen * 2)
                return MarkdownEditResult(
                    replaceRange: expandedRange,
                    replacement: inner,
                    newSelection: NSRange(location: expandedRange.location, length: (inner as NSString).length)
                )
            }
        }

        // 3. Wrap selection (or insert empty pair with cursor placed inside)
        let selectedText = ns.substring(with: selection)
        let replacement = "\(marker)\(selectedText)\(marker)"
        let newSelection: NSRange
        if selection.length == 0 {
            newSelection = NSRange(location: selection.location + mLen, length: 0)
        } else {
            newSelection = NSRange(location: selection.location + mLen, length: selection.length)
        }
        return MarkdownEditResult(
            replaceRange: selection,
            replacement: replacement,
            newSelection: newSelection
        )
    }

    // MARK: - Line Prefixes (Headings, Checklists, Bullets)

    private static func toggleHeading(
        level: Int?,
        in ns: NSString,
        selection: NSRange
    ) -> MarkdownEditResult {
        let lineRange = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let rawLine = ns.substring(with: lineRange)
        let hasNewline = rawLine.hasSuffix("\n")
        let contentLine = hasNewline ? String(rawLine.dropLast()) : rawLine
        let leadingSpaces = String(contentLine.prefix(while: { $0 == " " || $0 == "\t" }))
        let trimmed = String(contentLine.dropFirst(leadingSpaces.count))

        let existingLevel: Int
        let body: String
        if trimmed.hasPrefix("### ") {
            existingLevel = 3
            body = String(trimmed.dropFirst(4))
        } else if trimmed.hasPrefix("## ") {
            existingLevel = 2
            body = String(trimmed.dropFirst(3))
        } else if trimmed.hasPrefix("# ") {
            existingLevel = 1
            body = String(trimmed.dropFirst(2))
        } else {
            existingLevel = 0
            body = trimmed
        }

        let targetLevel: Int
        if let explicit = level {
            targetLevel = (existingLevel == explicit) ? 0 : max(1, min(3, explicit))
        } else {
            switch existingLevel {
            case 0: targetLevel = 2
            case 2: targetLevel = 3
            case 3: targetLevel = 1
            default: targetLevel = 0
            }
        }

        let prefix = targetLevel > 0 ? String(repeating: "#", count: targetLevel) + " " : ""
        let updatedContent = leadingSpaces + prefix + body
        let replacement = hasNewline ? updatedContent + "\n" : updatedContent
        let delta = (updatedContent as NSString).length - (contentLine as NSString).length
        let newCursor = max(lineRange.location, selection.location + delta)

        return MarkdownEditResult(
            replaceRange: lineRange,
            replacement: replacement,
            newSelection: NSRange(location: newCursor, length: 0)
        )
    }

    private static func toggleLinePrefix(
        _ targetPrefix: String,
        clearingPrefixes: [String],
        in ns: NSString,
        selection: NSRange
    ) -> MarkdownEditResult {
        let linesRange = ns.lineRange(for: selection)
        let blockText = ns.substring(with: linesRange)
        let hadTrailingNewline = blockText.hasSuffix("\n")
        let rawLines = (hadTrailingNewline ? String(blockText.dropLast()) : blockText)
            .components(separatedBy: "\n")

        let allHaveTarget = rawLines.allSatisfy { line in
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            return trimmed.hasPrefix(targetPrefix)
        }

        let transformed = rawLines.map { line -> String in
            let leading = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            var rest = String(line.dropFirst(leading.count))
            if allHaveTarget {
                if rest.hasPrefix(targetPrefix) {
                    rest = String(rest.dropFirst(targetPrefix.count))
                }
                return leading + rest
            } else {
                for other in clearingPrefixes where rest.hasPrefix(other) {
                    rest = String(rest.dropFirst(other.count))
                    break
                }
                if rest.hasPrefix(targetPrefix) {
                    return leading + rest
                }
                return leading + targetPrefix + rest
            }
        }

        let joined = transformed.joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")
        let newSelection: NSRange
        if rawLines.count == 1 && selection.length == 0 {
            let delta = (joined as NSString).length - (blockText as NSString).length
            newSelection = NSRange(location: max(linesRange.location, selection.location + delta), length: 0)
        } else {
            let bodyLen = (joined as NSString).length - (hadTrailingNewline ? 1 : 0)
            newSelection = NSRange(location: linesRange.location, length: max(0, bodyLen))
        }

        return MarkdownEditResult(
            replaceRange: linesRange,
            replacement: joined,
            newSelection: newSelection
        )
    }

    private static func toggleChecklistState(
        in ns: NSString,
        selection: NSRange
    ) -> MarkdownEditResult {
        let lineRange = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let lineText = ns.substring(with: lineRange)
        let nsLine = lineText as NSString

        if let regex = try? NSRegularExpression(pattern: #"^(\s*[-*]\s+)(\[[ xX]\])"#),
           let match = regex.firstMatch(in: lineText, range: NSRange(location: 0, length: nsLine.length)) {
            let boxLocal = match.range(at: 2)
            let boxGlobal = NSRange(location: lineRange.location + boxLocal.location, length: boxLocal.length)
            let current = nsLine.substring(with: boxLocal)
            let next = (current == "[ ]") ? "[x]" : "[ ]"
            return MarkdownEditResult(
                replaceRange: boxGlobal,
                replacement: next,
                newSelection: selection
            )
        }

        // Not a checklist yet -> convert current line to `- [ ] `
        return toggleLinePrefix("- [ ] ", clearingPrefixes: ["- ", "* "], in: ns, selection: selection)
    }

    // MARK: - Link

    private static func insertMarkdownLink(
        in ns: NSString,
        selection: NSRange
    ) -> MarkdownEditResult {
        let selected = ns.substring(with: selection)
        if selected.isEmpty {
            let replacement = "[](https://)"
            return MarkdownEditResult(
                replaceRange: selection,
                replacement: replacement,
                newSelection: NSRange(location: selection.location + 1, length: 0)
            )
        }

        // If user already selected a URL, put it in the URL slot and place cursor inside []
        if selected.hasPrefix("http://") || selected.hasPrefix("https://") {
            let replacement = "[](\(selected))"
            return MarkdownEditResult(
                replaceRange: selection,
                replacement: replacement,
                newSelection: NSRange(location: selection.location + 1, length: 0)
            )
        }

        let placeholderURL = "https://"
        let replacement = "[\(selected)](\(placeholderURL))"
        let urlLoc = selection.location + 1 + (selected as NSString).length + 2
        return MarkdownEditResult(
            replaceRange: selection,
            replacement: replacement,
            newSelection: NSRange(location: urlLoc, length: (placeholderURL as NSString).length)
        )
    }
}
