import SwiftUI
import MyBetterLifeCore

/// Modal presenting a newer GitHub release with its notes, one-click automatic install & relaunch
/// (on macOS `.app` bundles), and manual download fallback.
struct UpdateAvailableSheet: View {
    let release: AppReleaseInfo
    let updateChecker: AppUpdateChecker

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    #if os(macOS)
    @State private var installer = AppUpdateInstaller()
    #endif

    private var isInstalling: Bool {
        #if os(macOS)
        return installer.state.isBusy
        #else
        return false
        #endif
    }

    private var blocksDismissal: Bool {
        #if os(macOS)
        switch installer.state {
        case .verifying, .installing:
            return true
        case .idle, .downloading, .relaunching, .failed:
            return false
        }
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 26)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()

            notes

            Divider()

            actions
                .padding(20)
        }
        #if os(macOS)
        .frame(width: 480, height: 560)
        .interactiveDismissDisabled(blocksDismissal)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(L10n.updateAvailableTitle)
                .font(.title2.weight(.semibold))

            Text(release.title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text("v\(AppVersionInfo.shortVersion)")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text("v\(release.versionString)")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Da versão \(AppVersionInfo.shortVersion) para a versão \(release.versionString)")

            if let publishedAt = release.publishedAt {
                Text(publishedAt.formatted(.dateTime.day().month(.wide).year().locale(AppTheme.ptBRLocale)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var notes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.releaseNotesTitle)
                    .font(.headline)
                if release.notes.isEmpty {
                    Text(L10n.releaseNotesEmpty)
                        .foregroundStyle(.secondary)
                } else {
                    Text(renderedNotes)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            #if os(macOS)
            macOSPrimaryActionArea
            #else
            Button {
                openURL(release.downloadURL)
                dismiss()
            } label: {
                Label(L10n.downloadUpdate, systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            #endif

            HStack(spacing: 14) {
                Button(L10n.viewReleaseOnGitHub) {
                    openURL(release.releasePageURL)
                }
                #if os(macOS)
                .buttonStyle(.link)
                #else
                .buttonStyle(.borderless)
                #endif

                #if os(macOS)
                if release.isDirectInstaller && installer.canInstallInPlace {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Button(L10n.downloadManually) {
                        openURL(release.downloadURL)
                    }
                    .buttonStyle(.link)
                }
                #endif
            }
            .font(.caption)
            .disabled(isInstalling)

            HStack {
                Button(L10n.skipThisVersion) {
                    updateChecker.skipVersion(release.versionString)
                    dismiss()
                }
                .foregroundStyle(.secondary)
                .disabled(isInstalling)

                Spacer()

                Button(L10n.remindLater) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isInstalling)
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var macOSPrimaryActionArea: some View {
        switch installer.state {
        case .idle:
            if release.isDirectInstaller && installer.canInstallInPlace {
                Button {
                    installer.installAndRelaunch(release)
                } label: {
                    Label(L10n.installAndRelaunch, systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    openURL(release.downloadURL)
                    dismiss()
                } label: {
                    Label(L10n.downloadUpdate, systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }

        case .downloading(let progress):
            VStack(spacing: 8) {
                if let progress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                HStack {
                    Text(progress.map { "Baixando v\(release.versionString)… \(Int($0 * 100))%" } ?? "Baixando v\(release.versionString)…")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.cancel) {
                        installer.cancel()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.medium))
                }
            }
            .padding(.vertical, 4)

        case .verifying:
            installStatusRow("Verificando integridade (SHA-256)…")

        case .installing:
            installStatusRow("Instalando My Better Life v\(release.versionString)…")

        case .relaunching:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Reiniciando My Better Life…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Encerrar agora") {
                    exit(0)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
            }
            .padding(.vertical, 6)

        case .failed(let message):
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        installer.installAndRelaunch(release)
                    } label: {
                        Label("Tentar novamente", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button {
                        openURL(release.downloadURL)
                        dismiss()
                    } label: {
                        Text(L10n.downloadManually)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private func installStatusRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 6)
    }
    #endif

    /// Release notes are GitHub Markdown; render inline styling and keep line breaks.
    private var renderedNotes: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: release.notes, options: options))
            ?? AttributedString(release.notes)
    }
}
