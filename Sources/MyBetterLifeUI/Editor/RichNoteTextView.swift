import SwiftUI
import UniformTypeIdentifiers
import MyBetterLifeCore

#if os(macOS)
import AppKit
#endif

/// Full-bleed live Markdown document canvas (Bear / Obsidian style):
/// - Live Markdown typography as you type (# headings, **bold**, *italic*, `code`, links, checklists)
/// - Click checkboxes directly in the document to toggle [ ] <-> [x]
/// - Auto-continues `- [ ] ` and `- ` lists on Enter
/// - Supports ⌘V image paste, drag-and-drop images, and file picker
public struct RichNoteEditorView: View {
    @Binding public var markdown: String
    public let attachments: [BlockAttachment]
    public let accentColor: Color
    public let availableWikiTargets: [StandaloneNote]
    public let excludingNoteID: UUID?
    public let onToggleChecklistLine: (Int) -> Void
    public let onAttachImage: (_ data: Data, _ fileName: String) -> Void
    public let onRemoveAttachment: (BlockAttachment) -> Void
    public let onOpenWikiLink: ((String) -> Void)?
    public let onCreateSubnoteInline: ((String) -> Void)?

    @Environment(\.openURL) private var openURL

    @State private var isRenderedPreview: Bool = false
    @State private var isFileImporterPresented: Bool = false
    @State private var isLinkPopoverPresented: Bool = false
    @State private var linkLabelDraft: String = ""
    @State private var linkURLDraft: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var expandedAttachment: BlockAttachment? = nil

    public init(
        markdown: Binding<String>,
        attachments: [BlockAttachment],
        accentColor: Color,
        availableWikiTargets: [StandaloneNote] = [],
        excludingNoteID: UUID? = nil,
        onToggleChecklistLine: @escaping (Int) -> Void,
        onAttachImage: @escaping (_ data: Data, _ fileName: String) -> Void,
        onRemoveAttachment: @escaping (BlockAttachment) -> Void,
        onOpenWikiLink: ((String) -> Void)? = nil,
        onCreateSubnoteInline: ((String) -> Void)? = nil
    ) {
        self._markdown = markdown
        self.attachments = attachments
        self.accentColor = accentColor
        self.availableWikiTargets = availableWikiTargets
        self.excludingNoteID = excludingNoteID
        self.onToggleChecklistLine = onToggleChecklistLine
        self.onAttachImage = onAttachImage
        self.onRemoveAttachment = onRemoveAttachment
        self.onOpenWikiLink = onOpenWikiLink
        self.onCreateSubnoteInline = onCreateSubnoteInline
    }

    private var attachmentMap: [UUID: BlockAttachment] {
        Dictionary(uniqueKeysWithValues: attachments.map { ($0.id, $0) })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            minimalMarkdownToolbar

            if !isRenderedPreview, let wikiQuery = SecondBrainEngine.activeWikiLinkQuery(in: markdown) {
                wikiAutocompleteBar(query: wikiQuery)
            }

            Group {
                if isRenderedPreview {
                    formattedMarkdownView
                } else {
                    ZStack(alignment: .topLeading) {
                        if markdown.isEmpty {
                            Text(L10n.notePlaceholder)
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                                .allowsHitTesting(false)
                        }

                        #if os(macOS)
                        LiveMarkdownMacTextView(
                            text: $markdown,
                            accentNSColor: NSColor(accentColor),
                            onPasteImage: { imageData in
                                onAttachImage(imageData, "imagem-\(Int(Date().timeIntervalSince1970)).png")
                            },
                            onOpenURL: { url in
                                if url.scheme == "mbl-wikilink" {
                                    let target = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
                                    onOpenWikiLink?(target)
                                } else {
                                    openURL(url)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, minHeight: 300)
                        #else
                        TextEditor(text: $markdown)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(maxWidth: .infinity, minHeight: 280)
                        #endif
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .background(accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleImageDrop(providers)
            }

            if !isRenderedPreview && !attachments.isEmpty {
                attachmentsGallery
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    onAttachImage(data, url.lastPathComponent)
                }
            }
        }
        .sheet(item: $expandedAttachment) { attachment in
            AttachmentLightboxSheet(attachment: attachment)
        }
    }

    // MARK: - Minimal Markdown Toolbar

    private var minimalMarkdownToolbar: some View {
        HStack(spacing: 6) {
            if !isRenderedPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        toolbarButton(systemImage: "number", help: L10n.insertHeading) {
                            appendBlockPrefix("## ")
                        }
                        toolbarButton(systemImage: "bold", help: L10n.insertBold) {
                            appendInlineSnippet("**texto**")
                        }
                        toolbarButton(systemImage: "italic", help: L10n.insertItalic) {
                            appendInlineSnippet("*texto*")
                        }
                        toolbarButton(systemImage: "checklist", help: L10n.insertChecklist) {
                            appendBlockPrefix("- [ ] ")
                        }
                        toolbarButton(systemImage: "list.bullet", help: "Lista") {
                            appendBlockPrefix("- ")
                        }

                        Divider()
                            .frame(height: 14)
                            .padding(.horizontal, 2)

                        Button {
                            isLinkPopoverPresented = true
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(L10n.insertLink)
                        .popover(isPresented: $isLinkPopoverPresented) {
                            linkPopoverContent
                        }

                        toolbarButton(systemImage: "photo", help: L10n.insertImage) {
                            isFileImporterPresented = true
                        }

                        toolbarButton(systemImage: "doc.on.clipboard", help: "Colar imagem do clipboard") {
                            if let pngData = PlatformHelpers.pngDataFromClipboard() {
                                onAttachImage(pngData, "colado-\(Int(Date().timeIntervalSince1970)).png")
                            }
                        }

                        toolbarButton(systemImage: "point.3.connected.trianglepath.dotted", help: "Citar ou criar subnota ([[ ou @)") {
                            appendInlineSnippet("[[")
                        }
                    }
                }
            } else {
                Text("Visualização formatada")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }

            // Single circular icon toggle: eye (switch to Formatted) <-> pencil (switch to MD)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRenderedPreview.toggle()
                }
            } label: {
                Image(systemName: isRenderedPreview ? "pencil" : "eye")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isRenderedPreview ? accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isRenderedPreview ? accentColor.opacity(0.14) : AppTheme.secondarySurface)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isRenderedPreview ? accentColor.opacity(0.35) : AppTheme.hairline.opacity(0.6),
                                lineWidth: 0.75
                            )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isRenderedPreview ? "Editar Markdown (⌘E)" : "Visualizar formatado (⌘E)")
            #if os(macOS)
            .keyboardShortcut("e", modifiers: .command)
            #endif
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline.opacity(0.6))
                .frame(height: 0.75)
        }
    }

    private func wikiAutocompleteBar(query: String) -> some View {
        let suggestions = SecondBrainEngine.suggestWikiTargets(
            matching: query,
            in: availableWikiTargets,
            excludingNoteID: excludingNoteID
        )
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactMatchExists = suggestions.contains(where: {
            SecondBrainEngine.normalizeKey($0.title) == SecondBrainEngine.normalizeKey(trimmedQuery)
        })

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(suggestions) { target in
                    Button {
                        markdown = SecondBrainEngine.completeTrailingWikiLink(in: markdown, with: target.title)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: target.isGlobal ? "globe" : "doc.text")
                                .font(.system(size: 10, weight: .semibold))
                            Text(target.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(target.isGlobal ? accentColor : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(target.isGlobal ? accentColor.opacity(0.14) : AppTheme.secondarySurface)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !trimmedQuery.isEmpty && !exactMatchExists {
                    Button {
                        markdown = SecondBrainEngine.completeTrailingWikiLink(in: markdown, with: trimmedQuery)
                        onCreateSubnoteInline?(trimmedQuery)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: onCreateSubnoteInline != nil ? "doc.badge.plus" : "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(onCreateSubnoteInline != nil ? "Criar subnota \"\(trimmedQuery)\"" : "Criar \"\(trimmedQuery)\"")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(AppTheme.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Formatted Markdown Reader View

    private var formattedMarkdownView: some View {
        let lines = RichNoteDocument.parseLines(from: markdown)
        let renderedAttachmentIDs = Set(lines.compactMap { line -> UUID? in
            if case .image(_, let id, _) = line { return id }
            return nil
        })
        let orphanAttachments = attachments.filter { !renderedAttachmentIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 8) {
            if lines.isEmpty && attachments.isEmpty {
                Text("Nenhum conteúdo ainda. Clique em MD para começar a escrever.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(lines) { line in
                    formattedLineView(line)
                }

                ForEach(orphanAttachments) { attachment in
                    formattedAttachmentView(attachment, caption: "")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "mbl-wikilink" {
                let target = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
                onOpenWikiLink?(target)
                return .handled
            }
            return .systemAction
        })
    }

    @ViewBuilder
    private func formattedLineView(_ line: RichNoteLine) -> some View {
        switch line {
        case .empty:
            Spacer().frame(height: 6)

        case .heading(_, let level, let text):
            formattedInlineText(text)
                .font(
                    level == 1
                        ? .title2.weight(.bold)
                        : (level == 2 ? .title3.weight(.semibold) : .headline.weight(.semibold))
                )
                .foregroundStyle(.primary)
                .padding(.top, level == 1 ? 6 : 3)
                .textSelection(.enabled)

        case .checklist(let lineIndex, let isChecked, let text):
            Button {
                onToggleChecklistLine(lineIndex)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isChecked ? accentColor : .secondary)
                    formattedInlineText(text)
                        .font(.system(size: 14))
                        .strikethrough(isChecked, color: .secondary)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case .bullet(_, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
                formattedInlineText(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

        case .image(_, let attachmentID, let caption):
            if let attachment = attachmentMap[attachmentID] {
                formattedAttachmentView(attachment, caption: caption)
            }

        case .paragraph(_, let text):
            formattedInlineText(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    private func formattedInlineText(_ raw: String) -> Text {
        // Convert [[WikiLink]] to clickable Markdown links using custom scheme
        var transformed = raw
        if let regex = try? NSRegularExpression(pattern: #"\[\[([^\]\n]+)\]\]"#) {
            let ns = transformed as NSString
            let matches = regex.matches(in: transformed, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                let inner = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let encoded = inner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let swiftRange = Range(match.range, in: transformed) {
                    transformed.replaceSubrange(swiftRange, with: "[\(inner)](mbl-wikilink://open/\(encoded))")
                }
            }
        }
        if let attributed = try? AttributedString(
            markdown: transformed,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(raw)
    }

    private func formattedAttachmentView(_ attachment: BlockAttachment, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let img = PlatformHelpers.swiftUIImage(from: attachment.imageData) {
                ZStack(alignment: .topTrailing) {
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onTapGesture {
                            expandedAttachment = attachment
                        }

                    Button {
                        onRemoveAttachment(attachment)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.6))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toolbarButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private var linkPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inserir Link")
                .font(.subheadline.weight(.semibold))
            TextField(L10n.linkLabelPlaceholder, text: $linkLabelDraft)
                .textFieldStyle(.roundedBorder)
            TextField(L10n.linkURLPlaceholder, text: $linkURLDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L10n.cancel) {
                    isLinkPopoverPresented = false
                }
                Button(L10n.add) {
                    let rawURL = linkURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawURL.isEmpty else { return }
                    let normalized = rawURL.contains("://") ? rawURL : "https://\(rawURL)"
                    let label = linkLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    let snippet = label.isEmpty ? normalized : "[\(label)](\(normalized))"
                    appendInlineSnippet(snippet)
                    linkLabelDraft = ""
                    linkURLDraft = ""
                    isLinkPopoverPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(linkURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    // MARK: - Inline Image Gallery

    private var attachmentsGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            ForEach(attachments) { attachment in
                if let img = PlatformHelpers.swiftUIImage(from: attachment.imageData) {
                    ZStack(alignment: .topTrailing) {
                        img
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture {
                                expandedAttachment = attachment
                            }

                        Button {
                            onRemoveAttachment(attachment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.callout)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.6))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func appendBlockPrefix(_ prefix: String) {
        if markdown.isEmpty || markdown.hasSuffix("\n") {
            markdown += prefix
        } else {
            markdown += "\n" + prefix
        }
    }

    private func appendInlineSnippet(_ snippet: String) {
        if markdown.isEmpty || markdown.hasSuffix(" ") || markdown.hasSuffix("\n") {
            markdown += snippet
        } else {
            markdown += " " + snippet
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, let data = try? Data(contentsOf: url) else { return }
                    let fileName = url.lastPathComponent
                    DispatchQueue.main.async {
                        onAttachImage(data, fileName)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async {
                        onAttachImage(data, "anexo-\(Int(Date().timeIntervalSince1970)).png")
                    }
                }
            }
        }
        return handled
    }
}

/// Full-size preview sheet when tapping an attached image.
private struct AttachmentLightboxSheet: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: BlockAttachment

    var body: some View {
        NavigationStack {
            Group {
                if let img = PlatformHelpers.swiftUIImage(from: attachment.imageData) {
                    img
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvasBackground)
            .navigationTitle(attachment.fileName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif
    }
}

#if os(macOS)
// MARK: - Live-Styled Markdown NSTextView (Bear / Obsidian style)

private final class ConstrainedMarkdownScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 360)
    }

    override func layout() {
        super.layout()
        if let textView = documentView as? NSTextView {
            let width = max(140, contentSize.width)
            if abs(textView.frame.width - width) > 0.5 {
                textView.frame.size.width = width
            }
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
    }
}

private struct LiveMarkdownMacTextView: NSViewRepresentable {
    @Binding var text: String
    let accentNSColor: NSColor
    let onPasteImage: (Data) -> Void
    let onOpenURL: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ConstrainedMarkdownScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textView = LiveMarkdownNSTextView()
        textView.delegate = context.coordinator
        textView.onPasteImage = onPasteImage
        textView.onOpenURL = onOpenURL
        textView.accentNSColor = accentNSColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 2, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 340)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
        textView.linkTextAttributes = [
            .foregroundColor: accentNSColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]

        textView.string = text
        textView.restyleMarkdown()

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? LiveMarkdownNSTextView else { return }
        context.coordinator.parent = self
        textView.onPasteImage = onPasteImage
        textView.onOpenURL = onOpenURL

        let accentChanged = textView.accentNSColor != accentNSColor
        textView.accentNSColor = accentNSColor
        textView.linkTextAttributes = [
            .foregroundColor: accentNSColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]

        if textView.string != text {
            let savedSelection = textView.selectedRanges
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            textView.restyleMarkdown()
            let maxLen = (text as NSString).length
            let clampedSelection = savedSelection.map { rangeVal -> NSValue in
                let r = rangeVal.rangeValue
                let loc = min(r.location, maxLen)
                let len = min(r.length, maxLen - loc)
                return NSValue(range: NSRange(location: loc, length: len))
            }
            textView.selectedRanges = clampedSelection
            context.coordinator.isProgrammaticUpdate = false
        } else if accentChanged {
            textView.restyleMarkdown()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LiveMarkdownMacTextView
        var isProgrammaticUpdate = false

        init(_ parent: LiveMarkdownMacTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate,
                  let textView = notification.object as? LiveMarkdownNSTextView else { return }
            let current = textView.string
            textView.restyleMarkdown()
            if parent.text != current {
                parent.text = current
            }
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                parent.onOpenURL(url)
                return true
            } else if let str = link as? String, let url = URL(string: str) {
                parent.onOpenURL(url)
                return true
            }
            return false
        }
    }
}

private final class LiveMarkdownNSTextView: NSTextView {
    var onPasteImage: ((Data) -> Void)?
    var onOpenURL: ((URL) -> Void)?
    var accentNSColor: NSColor = .controlAccentColor

    private static let baseFont = NSFont.systemFont(ofSize: 14, weight: .regular)
    private static let boldFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
    private static let italicFont: NSFont = {
        NSFontManager.shared.convert(NSFont.systemFont(ofSize: 14, weight: .regular), toHaveTrait: .italicFontMask)
    }()
    private static let codeFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    private static let h1Font = NSFont.systemFont(ofSize: 20, weight: .bold)
    private static let h2Font = NSFont.systemFont(ofSize: 16.5, weight: .semibold)
    private static let h3Font = NSFont.systemFont(ofSize: 14.5, weight: .semibold)

    private static let baseParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4.5
        style.paragraphSpacing = 4
        return style
    }()

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        // Paste image directly if clipboard has an image and no text
        if let image = NSImage(pasteboard: pb),
           pb.string(forType: .string) == nil,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            onPasteImage?(png)
            return
        }
        // Always paste plain text so Markdown remains clean
        pasteAsPlainText(sender)
    }

    override func insertNewline(_ sender: Any?) {
        let nsText = string as NSString
        let sel = selectedRange()
        let lineRange = nsText.lineRange(for: NSRange(location: sel.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        // Smart Markdown list continuation for checklists and bullets
        let leadingSpaces = String(lineText.prefix(while: { $0 == " " || $0 == "\t" }))
        let trimmed = String(lineText.dropFirst(leadingSpaces.count))

        if trimmed == "- [ ]" || trimmed == "- [ ] " || trimmed == "- [x]" || trimmed == "- [x] " || trimmed == "-" || trimmed == "- " {
            // Empty list marker -> exit list cleanly
            let replaceRange = NSRange(location: lineRange.location, length: lineText.utf16.count)
            if shouldChangeText(in: replaceRange, replacementString: "") {
                textStorage?.replaceCharacters(in: replaceRange, with: "")
                didChangeText()
            }
            return
        }

        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            super.insertNewline(sender)
            insertText("\(leadingSpaces)- [ ] ", replacementRange: selectedRange())
            return
        }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let bullet = String(trimmed.prefix(2))
            super.insertNewline(sender)
            insertText("\(leadingSpaces)\(bullet)", replacementRange: selectedRange())
            return
        }

        super.insertNewline(sender)
    }

    override func mouseDown(with event: NSEvent) {
        // Allow clicking directly on `[ ]` or `[x]` to toggle a checklist item inline!
        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)
        let nsText = string as NSString

        if charIndex < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineString = nsText.substring(with: lineRange)
            if let regex = try? NSRegularExpression(pattern: #"^(\s*[-*]\s+)(\[[ xX]\])"#),
               let match = regex.firstMatch(in: lineString, range: NSRange(location: 0, length: (lineString as NSString).length)) {
                let boxLocalRange = match.range(at: 2)
                let boxGlobalRange = NSRange(
                    location: lineRange.location + boxLocalRange.location,
                    length: boxLocalRange.length
                )
                // Hit-test generously around `- [ ]`
                let hitStart = max(lineRange.location, boxGlobalRange.location - 2)
                let hitEnd = boxGlobalRange.location + boxGlobalRange.length + 1
                if charIndex >= hitStart && charIndex <= hitEnd {
                    let currentToken = nsText.substring(with: boxGlobalRange)
                    let replacement = (currentToken == "[ ]") ? "[x]" : "[ ]"
                    if shouldChangeText(in: boxGlobalRange, replacementString: replacement) {
                        textStorage?.replaceCharacters(in: boxGlobalRange, with: replacement)
                        didChangeText()
                        setSelectedRange(NSRange(location: boxGlobalRange.location + boxGlobalRange.length + 1, length: 0))
                    }
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }

    func restyleMarkdown() {
        guard let storage = textStorage else { return }
        let fullText = storage.string
        let fullLength = (fullText as NSString).length
        let fullRange = NSRange(location: 0, length: fullLength)

        storage.beginEditing()
        defer {
            storage.endEditing()
            typingAttributes = [
                .font: Self.baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: Self.baseParagraphStyle
            ]
        }

        guard fullLength > 0 else { return }

        // 1. Reset base styling
        storage.setAttributes([
            .font: Self.baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: Self.baseParagraphStyle
        ], range: fullRange)

        let mutedColor = NSColor.tertiaryLabelColor
        let secondaryColor = NSColor.secondaryLabelColor

        // 2. Line-level patterns (Headings, Checklists, Bullets, Attachment tokens)
        let nsText = fullText as NSString
        var pos = 0
        while pos < fullLength {
            let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .newlines)
            let lineLen = (trimmed as NSString).length
            let contentRange = NSRange(location: lineRange.location, length: lineLen)

            if trimmed.hasPrefix("# ") {
                storage.addAttribute(.font, value: Self.h1Font, range: contentRange)
                storage.addAttribute(.foregroundColor, value: mutedColor, range: NSRange(location: lineRange.location, length: 2))
            } else if trimmed.hasPrefix("## ") {
                storage.addAttribute(.font, value: Self.h2Font, range: contentRange)
                storage.addAttribute(.foregroundColor, value: mutedColor, range: NSRange(location: lineRange.location, length: 3))
            } else if trimmed.hasPrefix("### ") {
                storage.addAttribute(.font, value: Self.h3Font, range: contentRange)
                storage.addAttribute(.foregroundColor, value: mutedColor, range: NSRange(location: lineRange.location, length: 4))
            } else if let checkRegex = try? NSRegularExpression(pattern: #"^(\s*[-*]\s+\[)([ xX])(\]\s*)(.*)$"#),
                      let m = checkRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: lineLen)) {
                let markerRange = NSRange(location: lineRange.location, length: m.range(at: 1).length + m.range(at: 2).length + m.range(at: 3).length)
                let stateChar = (trimmed as NSString).substring(with: m.range(at: 2))
                let isChecked = stateChar.lowercased() == "x"
                let bodyRange = NSRange(location: lineRange.location + m.range(at: 4).location, length: m.range(at: 4).length)

                storage.addAttributes([
                    .font: Self.codeFont,
                    .foregroundColor: accentNSColor
                ], range: markerRange)

                if isChecked && bodyRange.length > 0 {
                    storage.addAttributes([
                        .foregroundColor: secondaryColor,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: secondaryColor
                    ], range: bodyRange)
                }
            } else if let bulletRegex = try? NSRegularExpression(pattern: #"^(\s*[-*]\s+)"#),
                      let m = bulletRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: lineLen)) {
                let markerRange = NSRange(location: lineRange.location, length: m.range(at: 1).length)
                storage.addAttribute(.foregroundColor, value: accentNSColor, range: markerRange)
            } else if trimmed.hasPrefix("![") && trimmed.contains("](attachment://") {
                storage.addAttributes([
                    .font: Self.codeFont,
                    .foregroundColor: mutedColor
                ], range: contentRange)
            }

            pos = NSMaxRange(lineRange)
        }

        // 3. Inline Bold: **text**
        applyRegex(#"(\*\*)([^\*\n]+)(\*\*)"#, in: fullText, storage: storage) { match in
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 1))
            storage.addAttribute(.font, value: Self.boldFont, range: match.range(at: 2))
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 3))
        }

        // 4. Inline Italic: *text*
        applyRegex(#"(?<!\*)(\*)([^\*\n]+)(\*)(?!\*)"#, in: fullText, storage: storage) { match in
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 1))
            storage.addAttribute(.font, value: Self.italicFont, range: match.range(at: 2))
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 3))
        }

        // 5. Inline Code: `code`
        applyRegex(#"(`)([^`\n]+)(`)"#, in: fullText, storage: storage) { match in
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 1))
            storage.addAttributes([
                .font: Self.codeFont,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.35)
            ], range: match.range(at: 2))
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 3))
        }

        // 6. Markdown Links: [label](https://...)
        applyRegex(#"(?<!!)(\[)([^\]]+)(\]\()(https?://[^\s\)]+)(\))"#, in: fullText, storage: storage) { match in
            let urlString = nsText.substring(with: match.range(at: 4))
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 1))
            storage.addAttributes([
                .foregroundColor: accentNSColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range(at: 2))
            if let url = URL(string: urlString) {
                storage.addAttribute(.link, value: url, range: match.range(at: 2))
            }
            let tailStart = match.range(at: 3).location
            let tailEnd = NSMaxRange(match.range(at: 5))
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: mutedColor
            ], range: NSRange(location: tailStart, length: tailEnd - tailStart))
        }

        // 7. Bare URLs
        applyRegex(#"(?<![\(\"])(https?://[^\s\)\]\>]+)"#, in: fullText, storage: storage) { match in
            let urlString = nsText.substring(with: match.range(at: 1))
            if let url = URL(string: urlString) {
                storage.addAttributes([
                    .link: url,
                    .foregroundColor: accentNSColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: match.range(at: 1))
            }
        }

        // 8. Second-Brain WikiLinks: [[Note Title]]
        applyRegex(#"(\[\[)([^\]\n]+)(\]\])"#, in: fullText, storage: storage) { match in
            let title = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 1))
            storage.addAttributes([
                .foregroundColor: accentNSColor,
                .font: Self.boldFont,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range(at: 2))
            if let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "mbl-wikilink://open/\(encoded)") {
                storage.addAttribute(.link, value: url, range: match.range(at: 2))
            }
            storage.addAttribute(.foregroundColor, value: mutedColor, range: match.range(at: 3))
        }
    }

    private func applyRegex(
        _ pattern: String,
        in text: String,
        storage: NSTextStorage,
        handler: (NSTextCheckingResult) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, range: range) {
            handler(match)
        }
    }
}
#endif
