import SwiftUI
import MyBetterLifeCore

/// Drag-and-drop payload encoder/decoder for dragging an Inbox item from the Sidebar onto the Day Timeline.
public enum InboxDragPayload {
    public static let prefix = "mbl-inbox:"

    public static func encode(_ itemID: UUID) -> String {
        "\(prefix)\(itemID.uuidString)"
    }

    public static func decode(_ string: String) -> UUID? {
        guard string.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(string.dropFirst(prefix.count)))
    }
}

/// Sidebar quick-capture Inbox section.
/// Capture unscheduled tasks in seconds and drag them straight onto any Day Timeline to time-block!
public struct InboxSidebarSection: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel

    @State private var newTaskTitle: String = ""
    @State private var isExpanded: Bool = true
    @State private var showCompleted: Bool = false

    public init(store: PlannerStore, viewModel: PlannerViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var pendingItems: [InboxItem] {
        store.inboxItems.filter { !$0.isCompleted }
    }

    private var completedItems: [InboxItem] {
        store.inboxItems.filter { $0.isCompleted }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                        Text(L10n.inboxSectionTitle.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                    }
                }
                .buttonStyle(.plain)

                if !pendingItems.isEmpty {
                    Text("\(pendingItems.count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }

                Spacer()

                if !completedItems.isEmpty && isExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCompleted.toggle()
                        }
                    } label: {
                        Image(systemName: showCompleted ? "eye.slash" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(showCompleted ? "Ocultar concluídas" : "Mostrar concluídas (\(completedItems.count))")
                }
            }
            .padding(.horizontal, 6)

            if isExpanded {
                // Inline quick-add field
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.5) : Color.accentColor)

                    TextField(L10n.inboxQuickAddPlaceholder, text: $newTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .onSubmit {
                            submitNewTask()
                        }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(AppTheme.secondarySurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if pendingItems.isEmpty && !showCompleted {
                    Text("Arraste tarefas daqui para a agenda")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                } else {
                    ForEach(pendingItems) { item in
                        inboxRow(item)
                    }

                    if showCompleted && !completedItems.isEmpty {
                        ForEach(completedItems.prefix(6)) { item in
                            inboxRow(item)
                        }
                    }
                }
            }
        }
    }

    private func inboxRow(_ item: InboxItem) -> some View {
        let color = Color(hex: store.category(for: item.categoryID)?.colorHex ?? AppTheme.defaultAccentHex)

        return HStack(spacing: 7) {
            Button {
                viewModel.toggleInboxCompletion(item, in: store)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.isCompleted ? color : .secondary)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(item.isCompleted ? .tertiary : .primary)
                .strikethrough(item.isCompleted)
                .lineLimit(2)

            Spacer(minLength: 4)

            if !item.isCompleted {
                Text(TimelineMath.formatDuration(minutes: item.estimatedMinutes))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.secondarySurface, in: Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppTheme.canvasBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.5), lineWidth: 0.6)
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onDrag {
            NSItemProvider(object: InboxDragPayload.encode(item.id) as NSString)
        } preview: {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(TimelineMath.formatDuration(minutes: item.estimatedMinutes))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
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
            if !item.isCompleted {
                Button {
                    viewModel.scheduleInboxItem(item, on: viewModel.selectedDate, in: store)
                } label: {
                    Label("Agendar no dia selecionado", systemImage: "calendar.badge.plus")
                }

                Menu {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                        Button {
                            viewModel.updateInboxItemDuration(item, minutes: mins, in: store)
                        } label: {
                            Label(
                                TimelineMath.formatDuration(minutes: mins),
                                systemImage: item.estimatedMinutes == mins ? "checkmark" : "clock"
                            )
                        }
                    }
                } label: {
                    Label("Duração estimada", systemImage: "clock")
                }

                if !store.globalNotes.isEmpty {
                    Menu {
                        Button {
                            viewModel.linkInboxItem(item, toGlobalNote: nil, in: store)
                        } label: {
                            Label("Nenhum", systemImage: item.globalNoteID == nil ? "checkmark" : "minus")
                        }
                        Divider()
                        ForEach(store.globalNotes) { global in
                            Button {
                                viewModel.linkInboxItem(item, toGlobalNote: global, in: store)
                            } label: {
                                Label(
                                    global.title.isEmpty ? L10n.untitledNote : global.title,
                                    systemImage: item.globalNoteID == global.id ? "checkmark" : "globe"
                                )
                            }
                        }
                    } label: {
                        Label("Vincular a Bloco Global", systemImage: "globe")
                    }
                }

                Divider()
            }

            Button {
                viewModel.toggleInboxCompletion(item, in: store)
            } label: {
                Label(item.isCompleted ? "Reabrir tarefa" : L10n.markCompleted, systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
            }

            Button(role: .destructive) {
                viewModel.deleteInboxItem(item, in: store)
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private func submitNewTask() {
        guard viewModel.createInboxItem(title: newTaskTitle, in: store) != nil else { return }
        newTaskTitle = ""
    }
}
