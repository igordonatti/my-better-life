import SwiftUI
import MyBetterLifeCore

/// Reusable right-click context menu for any block on the Day Timeline, All-Day strip, or Week View:
/// - Repeat submenu (Weekdays Mon–Fri, Daily, Choose days…, Stop repeating)
/// - Global Block actions (Make Global, Link to existing Global Block, Unlink)
/// - Complete toggle & Delete
public struct BlockContextMenuContent: View {
    public let occurrence: DayOccurrence
    public let globalNotes: [StandaloneNote]
    public let selectedCount: Int
    public let canPaste: Bool
    public let onToggleComplete: () -> Void
    public let onOpenInNewWindow: (() -> Void)?
    public let onCopy: (() -> Void)?
    public let onPaste: (() -> Void)?
    public let onStartFocus: ((FocusTimerMode) -> Void)?
    public let onChangeReminder: ((Int?) -> Void)?
    public let onQuickRecurrence: (RecurrenceRuleType?, WeekdayMask) -> Void
    public let onOpenCustomRecurrence: () -> Void
    public let onPromoteToGlobal: () -> Void
    public let onLinkToGlobal: (StandaloneNote) -> Void
    public let onUnlinkGlobal: () -> Void
    public let onDelete: () -> Void

    public init(
        occurrence: DayOccurrence,
        globalNotes: [StandaloneNote],
        selectedCount: Int = 1,
        canPaste: Bool = false,
        onToggleComplete: @escaping () -> Void,
        onOpenInNewWindow: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil,
        onPaste: (() -> Void)? = nil,
        onStartFocus: ((FocusTimerMode) -> Void)? = nil,
        onChangeReminder: ((Int?) -> Void)? = nil,
        onQuickRecurrence: @escaping (RecurrenceRuleType?, WeekdayMask) -> Void,
        onOpenCustomRecurrence: @escaping () -> Void,
        onPromoteToGlobal: @escaping () -> Void,
        onLinkToGlobal: @escaping (StandaloneNote) -> Void,
        onUnlinkGlobal: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.occurrence = occurrence
        self.globalNotes = globalNotes
        self.selectedCount = selectedCount
        self.canPaste = canPaste
        self.onToggleComplete = onToggleComplete
        self.onOpenInNewWindow = onOpenInNewWindow
        self.onCopy = onCopy
        self.onPaste = onPaste
        self.onStartFocus = onStartFocus
        self.onChangeReminder = onChangeReminder
        self.onQuickRecurrence = onQuickRecurrence
        self.onOpenCustomRecurrence = onOpenCustomRecurrence
        self.onPromoteToGlobal = onPromoteToGlobal
        self.onLinkToGlobal = onLinkToGlobal
        self.onUnlinkGlobal = onUnlinkGlobal
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: onToggleComplete) {
            Label(
                occurrence.isCompleted ? "Desmarcar conclusão" : L10n.markCompleted,
                systemImage: occurrence.isCompleted ? "circle" : "checkmark.circle"
            )
        }

        if let onOpenInNewWindow {
            Button(action: onOpenInNewWindow) {
                Label("Abrir em nova janela", systemImage: "arrow.up.forward.app")
            }
        }

        if let onCopy {
            Button(action: onCopy) {
                Label(
                    selectedCount > 1 ? "Copiar \(selectedCount) blocos (⌘C)" : "Copiar bloco (⌘C)",
                    systemImage: "doc.on.doc"
                )
            }
        }

        if let onPaste, canPaste {
            Button(action: onPaste) {
                Label("Colar neste dia (⌘V)", systemImage: "doc.on.clipboard")
            }
        }

        if let onStartFocus, !occurrence.isAllDay {
            Menu {
                Button {
                    onStartFocus(.blockDuration)
                } label: {
                    Label("Tempo do bloco", systemImage: "timer")
                }
                Button {
                    onStartFocus(.pomodoro(workMinutes: 25, breakMinutes: 5))
                } label: {
                    Label("Pomodoro (25/5 min)", systemImage: "flame")
                }
            } label: {
                Label(L10n.startFocus, systemImage: "timer")
            }
        }

        if let onChangeReminder, !occurrence.isAllDay {
            let currentOption = ReminderOption.from(minutesBefore: occurrence.reminderMinutesBefore)
            Menu {
                ForEach(ReminderOption.allCases) { option in
                    Button {
                        onChangeReminder(option.minutesBefore)
                    } label: {
                        Label(
                            option.displayName,
                            systemImage: option == currentOption ? "checkmark" : "bell"
                        )
                    }
                }
            } label: {
                Label(
                    currentOption == .none ? L10n.reminder : "\(L10n.reminder): \(currentOption.displayName)",
                    systemImage: currentOption == .none ? "bell.slash" : "bell.fill"
                )
            }
        }

        Divider()

        Menu {
            Button {
                onQuickRecurrence(.weekdays, .weekdays)
            } label: {
                Label("Dias úteis (Seg–Sex)", systemImage: "calendar.badge.clock")
            }

            Button {
                onQuickRecurrence(.daily, .all)
            } label: {
                Label("Todos os dias", systemImage: "repeat")
            }

            Button {
                onOpenCustomRecurrence()
            } label: {
                Label("Escolher dias da semana…", systemImage: "slider.horizontal.3")
            }

            if occurrence.isRecurring {
                Divider()
                Button(role: .destructive) {
                    onQuickRecurrence(nil, [])
                } label: {
                    Label("Parar de repetir", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label(
                occurrence.isRecurring ? "Repetir (\(occurrence.series?.ruleType.displayName ?? "Ativo"))" : "Repetir pela semana",
                systemImage: "repeat"
            )
        }

        if occurrence.isGlobalLinked {
            Button(action: onUnlinkGlobal) {
                Label(L10n.unlinkGlobalBlock, systemImage: "globe.badge.chevron.backward")
            }
        } else {
            Button(action: onPromoteToGlobal) {
                Label(L10n.makeGlobalBlock, systemImage: "globe")
            }

            if !globalNotes.isEmpty {
                Menu {
                    ForEach(globalNotes) { global in
                        Button {
                            onLinkToGlobal(global)
                        } label: {
                            Label(global.title.isEmpty ? L10n.untitledNote : global.title, systemImage: "globe")
                        }
                    }
                } label: {
                    Label(L10n.linkToGlobalBlock, systemImage: "link")
                }
            }
        }

        Divider()

        Button(role: .destructive, action: onDelete) {
            Label(L10n.deleteBlock, systemImage: "trash")
        }
    }
}
