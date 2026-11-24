import SwiftUI
import Observation
import MyBetterLifeCore
#if os(macOS)
import AppKit
#endif

/// Identifies a specific Agenda block, recurring occurrence, or Standalone/Global Note
/// that can be popped out into an independent macOS window (Slack-style pop-out window).
public enum DetachedEditorTarget: Hashable, Codable, Sendable {
    public static let windowID = "detached-editor"

    case block(UUID)
    case virtualOccurrence(seriesID: UUID, dayStart: Date)
    case standaloneNote(UUID)

    public init?(from ref: SelectedItemRef) {
        switch ref {
        case .block(let id):
            self = .block(id)
        case .virtualOccurrence(let seriesID, let dayStart):
            self = .virtualOccurrence(seriesID: seriesID, dayStart: dayStart)
        }
    }
}

/// Coordinates pop-out positioning (for tear-off tab drags) and docking back into the main app window.
@Observable
@MainActor
public final class DetachedWindowCoordinator {
    /// Set by a detached window when the user clicks "Encaixar de volta"; observed by `MyBetterLifeRootView`.
    public var pendingDockBackTarget: DetachedEditorTarget? = nil

    /// Optional screen-space drop point (AppKit coordinates) captured when tearing off a tab so the new
    /// window spawns right where the user released the mouse.
    @ObservationIgnored
    private var pendingDropPoints: [DetachedEditorTarget: CGPoint] = [:]

    public init() {}

    public func registerDropPoint(_ point: CGPoint, for target: DetachedEditorTarget) {
        pendingDropPoints[target] = point
    }

    public func consumeDropPoint(for target: DetachedEditorTarget) -> CGPoint? {
        pendingDropPoints.removeValue(forKey: target)
    }

    public func requestDockBack(_ target: DetachedEditorTarget) {
        pendingDockBackTarget = target
    }
}

#if os(macOS)
/// Independent pop-out editor window on macOS (Slack-style):
/// - Edits the exact same live `PlannerStore` in real time alongside the main window
/// - Internal Back/Forward (`←` / `→`) navigation stack for subnotes, breadcrumbs, and `[[wikilinks]]`
/// - "Encaixar de volta" button to dock the note/block back into the main app window
/// - "Sempre no topo" (`pin`) toggle to float above terminal/browser/IDE
/// - `⌘W` natively closes only this detached window without touching the main app window
public struct DetachedEditorWindowView: View {
    public let initialTarget: DetachedEditorTarget
    public let store: PlannerStore
    public let focusManager: FocusSessionManager
    public let windowCoordinator: DetachedWindowCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var localViewModel = PlannerViewModel()
    @State private var history: [DetachedEditorTarget]
    @State private var historyIndex: Int = 0
    @State private var isPinnedOnTop: Bool = false
    @State private var exportDocument: MarkdownFileDocument? = nil
    @State private var exportFilename: String = "nota.md"
    @State private var isExportPresented: Bool = false
    @State private var hasAppliedInitialPosition: Bool = false

    public init(
        target: DetachedEditorTarget,
        store: PlannerStore,
        focusManager: FocusSessionManager,
        windowCoordinator: DetachedWindowCoordinator = DetachedWindowCoordinator()
    ) {
        self.initialTarget = target
        self.store = store
        self.focusManager = focusManager
        self.windowCoordinator = windowCoordinator
        self._history = State(initialValue: [target])
    }

    private var currentTarget: DetachedEditorTarget {
        guard history.indices.contains(historyIndex) else { return initialTarget }
        return history[historyIndex]
    }

    private var canGoBack: Bool { historyIndex > 0 }
    private var canGoForward: Bool { historyIndex < history.count - 1 }

    private var resolvedOccurrence: DayOccurrence? {
        switch currentTarget {
        case .block(let id):
            return localViewModel.resolveOccurrence(for: .block(id), in: store)
        case .virtualOccurrence(let seriesID, let dayStart):
            return localViewModel.resolveOccurrence(for: .virtualOccurrence(seriesID: seriesID, dayStart: dayStart), in: store)
        case .standaloneNote:
            return nil
        }
    }

    private var resolvedStandaloneItem: UnifiedNoteItem? {
        guard case .standaloneNote(let noteID) = currentTarget,
              let note = store.note(for: noteID) else {
            return nil
        }
        return NotesLibraryEngine.items(
            notes: [note],
            blocks: [],
            categories: store.categories,
            attachments: store.attachments,
            originFilter: .all
        ).first
    }

    private var windowTitle: String {
        if let occ = resolvedOccurrence {
            let base = occ.title.isEmpty ? L10n.untitledBlock : occ.title
            return "\(base) · \(AppTheme.shortDate(occ.dayStart))"
        }
        if let item = resolvedStandaloneItem {
            return item.title.isEmpty ? L10n.untitledNote : item.title
        }
        return L10n.appName
    }

    public var body: some View {
        VStack(spacing: 0) {
            detachedTopBar

            if let occ = resolvedOccurrence {
                BlockInspectorView(
                    store: store,
                    occurrence: occ,
                    viewModel: localViewModel,
                    focusManager: focusManager,
                    showCloseButton: false,
                    isDetachedWindow: true
                )
            } else if let item = resolvedStandaloneItem {
                UnifiedNoteEditorView(
                    store: store,
                    item: item,
                    viewModel: localViewModel,
                    isDetachedWindow: true,
                    onExport: {
                        exportDocument = MarkdownFileDocument(title: item.title, markdown: item.noteMarkdown)
                        exportFilename = MarkdownFileDocument.sanitizedFilename(from: item.title)
                        isExportPresented = true
                    }
                )
            } else {
                ContentUnavailableView(
                    "Item não encontrado",
                    systemImage: "doc.questionmark",
                    description: Text("Este bloco ou nota foi removido.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 380, minHeight: 420)
        .background(AppTheme.canvasBackground)
        .background(
            DetachedWindowHostConfigurator(
                isFloating: isPinnedOnTop,
                onWindowReady: { window in
                    guard !hasAppliedInitialPosition else { return }
                    hasAppliedInitialPosition = true
                    if let dropPoint = windowCoordinator.consumeDropPoint(for: initialTarget) {
                        positionWindow(window, nearScreenPoint: dropPoint)
                    }
                }
            )
        )
        .navigationTitle(windowTitle)
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .markdownDocument,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
        .onChange(of: localViewModel.selectedNoteItemID) { _, newID in
            // Navigate internally inside this detached window when clicking subnotes, breadcrumbs, or [[wikilinks]]
            guard let newID, newID.hasPrefix("note-"),
                  let uuid = UUID(uuidString: String(newID.dropFirst(5))) else { return }
            let next = DetachedEditorTarget.standaloneNote(uuid)
            if next != currentTarget {
                pushToHistory(next)
            }
        }
        .onChange(of: localViewModel.selectedItem) { _, newRef in
            // Navigate internally when clicking a scheduled Agenda session from a Global Block
            guard let newRef, let next = DetachedEditorTarget(from: newRef) else { return }
            if next != currentTarget {
                pushToHistory(next)
            }
        }
    }

    private func pushToHistory(_ next: DetachedEditorTarget) {
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        history.append(next)
        historyIndex = history.count - 1
    }

    private func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
    }

    private func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
    }

    private func dockBackToMainWindow() {
        let targetToDock = currentTarget
        windowCoordinator.requestDockBack(targetToDock)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        dismiss()
    }

    private func positionWindow(_ window: NSWindow, nearScreenPoint point: CGPoint) {
        let size = window.frame.size
        var origin = CGPoint(x: point.x - size.width * 0.5, y: point.y - size.height + 24)
        if let screenFrame = (NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main)?.visibleFrame {
            origin.x = max(screenFrame.minX + 12, min(screenFrame.maxX - size.width - 12, origin.x))
            origin.y = max(screenFrame.minY + 12, min(screenFrame.maxY - size.height - 12, origin.y))
        }
        window.setFrameOrigin(origin)
    }

    private var detachedTopBar: some View {
        HStack(spacing: 8) {
            // Internal Back / Forward navigation buttons
            HStack(spacing: 2) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(canGoBack ? .primary : .quaternary)
                .disabled(!canGoBack)
                .help("Voltar")

                Button {
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(canGoForward ? .primary : .quaternary)
                .disabled(!canGoForward)
                .help("Avançar")
            }

            Divider()
                .frame(height: 14)

            if let occ = resolvedOccurrence {
                HStack(spacing: 5) {
                    Image(systemName: occ.isGlobalLinked ? "globe" : "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: occ.category?.colorHex ?? AppTheme.defaultAccentHex))
                    Text(AppTheme.shortDate(occ.dayStart))
                        .font(.caption.weight(.semibold))
                    if !occ.isAllDay {
                        Text("· \(TimelineMath.formatTimeRange(start: occ.startDate, end: occ.endDate))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let item = resolvedStandaloneItem {
                HStack(spacing: 5) {
                    Image(systemName: item.isGlobal ? "globe" : "doc.text")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: item.category?.colorHex ?? AppTheme.defaultAccentHex))
                    Text(item.isGlobal ? "Bloco Global" : "Nota")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                dockBackToMainWindow()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.caption2.weight(.semibold))
                    Text("Encaixar")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.secondarySurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Encaixar de volta na janela principal do My Better Life")

            Button {
                isPinnedOnTop.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPinnedOnTop ? "pin.fill" : "pin")
                        .font(.caption2.weight(.semibold))
                    Text(isPinnedOnTop ? "No topo" : "Fixar")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(isPinnedOnTop ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (isPinnedOnTop ? Color.accentColor.opacity(0.14) : AppTheme.secondarySurface),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .help("Manter esta janela flutuando acima dos outros aplicativos")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.secondarySurface.opacity(0.45))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }
}

/// Applies `NSWindow.level = .floating` dynamically and positions a freshly torn-off window near the drop point.
private struct DetachedWindowHostConfigurator: NSViewRepresentable {
    let isFloating: Bool
    let onWindowReady: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = isFloating ? .floating : .normal
                onWindowReady(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = isFloating ? .floating : .normal
                onWindowReady(window)
            }
        }
    }
}
#endif
