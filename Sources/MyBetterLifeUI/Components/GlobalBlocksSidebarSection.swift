import SwiftUI
import MyBetterLifeCore

/// Drag-and-drop payload encoder/decoder for dragging a Global Block from the Sidebar onto the Day Timeline.
public enum GlobalBlockDragPayload {
    public static let prefix = "mbl-global:"

    public static func encode(_ noteID: UUID) -> String {
        "\(prefix)\(noteID.uuidString)"
    }

    public static func decode(_ string: String) -> UUID? {
        guard string.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(string.dropFirst(prefix.count)))
    }
}

/// Sidebar section displaying reusable Global Blocks (Second Brain Hubs).
/// Click to open in Notes, or drag onto any Day Timeline on macOS to schedule a session linked to that Global Block!
public struct GlobalBlocksSidebarSection: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init(store: PlannerStore, viewModel: PlannerViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var globalNotes: [StandaloneNote] {
        store.globalNotes.sorted { $0.updatedAt > $1.updatedAt }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.globalSectionTitle.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Spacer()
                Button {
                    viewModel.createGlobalBlock(in: store)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.newGlobalBlock)
            }
            .padding(.horizontal, 6)

            if globalNotes.isEmpty {
                Button {
                    viewModel.createGlobalBlock(in: store)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Criar bloco global")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                ForEach(globalNotes) { note in
                    globalRow(for: note)
                }
            }
        }
    }

    private func globalRow(for note: StandaloneNote) -> some View {
        let color = Color(hex: store.category(for: note.categoryID)?.colorHex ?? AppTheme.defaultAccentHex)
        let isActiveInNotes = viewModel.selectedSection == .notes && viewModel.selectedNoteItemID == "note-\(note.id.uuidString)"

        return HStack(spacing: 9) {
            Image(systemName: "globe")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)

            Text(note.title.isEmpty ? L10n.untitledNote : note.title)
                .font(.subheadline.weight(isActiveInNotes ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            let sessionCount = store.blocks.filter { $0.globalNoteID == note.id && !$0.isDeletedOverride }.count
            if sessionCount > 0 {
                Text("\(sessionCount)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if isActiveInNotes {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.openGlobalNoteInNotes(note)
        }
        #if os(macOS)
        .onDrag {
            NSItemProvider(object: GlobalBlockDragPayload.encode(note.id) as NSString)
        } preview: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(note.title.isEmpty ? L10n.untitledNote : note.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.canvasBackground, in: Capsule())
            .overlay {
                Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1)
            }
        }
        #endif
        .contextMenu {
            #if os(macOS)
            Button {
                openWindow(id: DetachedEditorTarget.windowID, value: DetachedEditorTarget.standaloneNote(note.id))
            } label: {
                Label("Abrir em nova janela", systemImage: "arrow.up.forward.app")
            }
            #endif

            Button {
                viewModel.scheduleGlobalBlock(note, on: viewModel.selectedDate, in: store)
            } label: {
                Label("Agendar no dia selecionado", systemImage: "calendar.badge.plus")
            }

            Button {
                viewModel.openGlobalNoteInNotes(note)
            } label: {
                Label("Abrir em Notas", systemImage: "doc.text")
            }

            Divider()

            Button {
                viewModel.toggleGlobalFlag(for: note, in: store)
            } label: {
                Label("Remover de Globais", systemImage: "globe.badge.chevron.backward")
            }
        }
    }
}
