import SwiftUI
import MyBetterLifeCore

/// Sleek floating banner shown at the top of the workspace whenever Focus Mode is running.
public struct FocusActiveBannerView: View {
    public let focusManager: FocusSessionManager
    public let store: PlannerStore

    public init(focusManager: FocusSessionManager, store: PlannerStore) {
        self.focusManager = focusManager
        self.store = store
    }

    private var accentColor: Color {
        Color(hex: focusManager.activeAccentHex)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(focusManager.isPaused ? Color.orange : accentColor)
                        .frame(width: 8, height: 8)

                    Text(focusManager.phase.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .tracking(0.5)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.14), in: Capsule())

                Text(focusManager.activeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(focusManager.formattedRemaining)
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(focusManager.remainingSeconds == 0 ? .orange : .primary)

                HStack(spacing: 6) {
                    Button {
                        focusManager.togglePause()
                    } label: {
                        Image(systemName: focusManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.semibold))
                            .frame(width: 26, height: 26)
                            .background(AppTheme.secondarySurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(focusManager.isPaused ? L10n.resumeFocus : L10n.pauseFocus)

                    Button {
                        focusManager.extend(minutes: 15, in: store)
                    } label: {
                        Text(L10n.extend15Min)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.secondarySurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Estender bloco e timer em 15 minutos")

                    Button {
                        focusManager.completeActiveBlock(in: store)
                    } label: {
                        Label("Concluir", systemImage: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusManager.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.stopFocus)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)

            // Crisp progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(accentColor.opacity(0.12))
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: geo.size.width * focusManager.progress)
                        .animation(.linear(duration: 0.4), value: focusManager.progress)
                }
            }
            .frame(height: 2.5)
        }
        .background(AppTheme.canvasBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }
}

/// Interactive in-app reminder banner (used when running via `make run` outside a `.app` bundle).
public struct InAppReminderBannerView: View {
    public let alert: InAppReminderAlert
    public let onAction: (ReminderNotificationAction) -> Void
    public let onDismiss: () -> Void

    public init(
        alert: InAppReminderAlert,
        onAction: @escaping (ReminderNotificationAction) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.alert = alert
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(alert.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onAction(.startFocus)
            } label: {
                Label("Iniciar Foco", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onAction(.snooze15Minutes)
            } label: {
                Text("Adiar 15m")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.secondarySurface, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onAction(.markCompleted)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Marcar como concluído")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }
}
