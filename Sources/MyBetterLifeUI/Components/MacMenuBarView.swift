#if os(macOS)
import SwiftUI
import AppKit
import MyBetterLifeCore

/// Dynamic label rendered directly in the macOS top Menu Bar:
/// - Active Focus Mode: timer icon + remaining countdown (`24:18`) + short title
/// - Scheduled block right now: crisp dot + short title
/// - Idle: clean minimal icon
public struct MacMenuBarLabel: View {
    public let focusManager: FocusSessionManager

    public init(focusManager: FocusSessionManager) {
        self.focusManager = focusManager
    }

    public var body: some View {
        if focusManager.isActive {
            Label(
                "\(focusManager.formattedRemaining) · \(shortTitle(focusManager.activeTitle))",
                systemImage: focusManager.isPaused ? "pause.circle.fill" : "timer"
            )
        } else if let summary = focusManager.scheduledMenuBarSummary {
            Label(summary, systemImage: "calendar.badge.clock")
        } else {
            Image(systemName: "sparkles")
        }
    }

    private func shortTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Foco" : trimmed
        return title.count > 16 ? String(title.prefix(15)) + "…" : title
    }
}

/// Rich macOS Menu Bar popover (`MenuBarExtra` with `.window` style):
/// - Live Focus Mode controls OR one-click start on the current scheduled block
/// - Upcoming blocks for today
/// - Instant Quick Capture directly into the synced Inbox
/// - Open Main Window & Quit actions
public struct MacMenuBarPopoverView: View {
    public let store: PlannerStore
    public let focusManager: FocusSessionManager
    public let onOpenMainWindow: () -> Void

    @State private var quickInboxText: String = ""
    @State private var justCapturedMessage: String? = nil

    public init(
        store: PlannerStore,
        focusManager: FocusSessionManager,
        onOpenMainWindow: @escaping () -> Void
    ) {
        self.store = store
        self.focusManager = focusManager
        self.onOpenMainWindow = onOpenMainWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            focusOrNowCard
            upcomingSection
            quickCaptureSection
            Divider()
            footerActions
        }
        .padding(14)
        .frame(width: 324)
        .background(AppTheme.canvasBackground)
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(L10n.appName)
                    .font(.subheadline.weight(.bold))
            }
            Spacer()
            Text(AppTheme.shortDate(Date()))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var focusOrNowCard: some View {
        if focusManager.isActive {
            let accent = Color(hex: focusManager.activeAccentHex)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(focusManager.phase.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.14), in: Capsule())
                    Spacer()
                    Text(focusManager.formattedRemaining)
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                }

                Text(focusManager.activeTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                ProgressView(value: focusManager.progress)
                    .tint(accent)

                HStack(spacing: 6) {
                    Button {
                        focusManager.togglePause()
                    } label: {
                        Label(focusManager.isPaused ? "Retomar" : "Pausar", systemImage: focusManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("+15m") {
                        focusManager.extend(minutes: 15, in: store)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        focusManager.completeActiveBlock(in: store)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Concluir bloco")

                    Button {
                        focusManager.stop()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Encerrar Foco")
                }
            }
            .padding(11)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
            }
        } else if let current = focusManager.currentScheduledOccurrence(in: store) {
            let accent = Color(hex: current.category?.colorHex ?? AppTheme.defaultAccentHex)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("AGORA NA AGENDA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(TimelineMath.formatTimeRange(start: current.startDate, end: current.endDate))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(current.title.isEmpty ? L10n.untitledBlock : current.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Button {
                        focusManager.start(occurrence: current, mode: .blockDuration, in: store)
                    } label: {
                        Label("Iniciar Foco", systemImage: "timer")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        focusManager.start(occurrence: current, mode: .pomodoro(workMinutes: 25, breakMinutes: 5), in: store)
                    } label: {
                        Text("25m")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Iniciar Pomodoro 25/5")
                }
            }
            .padding(11)
            .background(AppTheme.secondarySurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Horário livre agora")
                        .font(.caption.weight(.semibold))
                    Text("Capture uma ideia abaixo ou abra a agenda.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.secondarySurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = focusManager.upcomingTodayOccurrences(in: store, limit: 3)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("PRÓXIMOS HOJE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                ForEach(upcoming) { occ in
                    let color = Color(hex: occ.category?.colorHex ?? AppTheme.defaultAccentHex)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 3, height: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(occ.title.isEmpty ? L10n.untitledBlock : occ.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(TimelineMath.formatTimeRange(start: occ.startDate, end: occ.endDate))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            focusManager.start(occurrence: occ, mode: .blockDuration, in: store)
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Iniciar Foco neste bloco")
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var quickCaptureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAPTURA RÁPIDA NA INBOX")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            HStack(spacing: 6) {
                TextField("Nova tarefa ou ideia…", text: $quickInboxText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(AppTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit {
                        submitQuickInbox()
                    }

                Button {
                    submitQuickInbox()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(quickInboxText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(quickInboxText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let msg = justCapturedMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var footerActions: some View {
        HStack {
            Button {
                onOpenMainWindow()
            } label: {
                Label("Abrir My Better Life", systemImage: "macwindow")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Spacer()

            Button("Encerrar") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func submitQuickInbox() {
        let trimmed = quickInboxText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (store.inboxItems.map(\.sortOrder).min() ?? 0) - 1
        let item = InboxItem(title: trimmed, estimatedMinutes: 30, sortOrder: nextOrder)
        store.upsertInboxItem(item)
        quickInboxText = ""
        justCapturedMessage = "Salvo na Inbox ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            justCapturedMessage = nil
        }
    }
}
#endif
