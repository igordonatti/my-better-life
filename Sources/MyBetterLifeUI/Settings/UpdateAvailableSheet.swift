import SwiftUI
import MyBetterLifeCore

/// Modal presenting a newer GitHub release with its notes and download actions.
struct UpdateAvailableSheet: View {
    let release: AppReleaseInfo
    let updateChecker: AppUpdateChecker

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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
        .frame(width: 480, height: 540)
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

            Button(L10n.viewReleaseOnGitHub) {
                openURL(release.releasePageURL)
            }
            #if os(macOS)
            .buttonStyle(.link)
            #else
            .buttonStyle(.borderless)
            #endif

            HStack {
                Button(L10n.skipThisVersion) {
                    updateChecker.skipVersion(release.versionString)
                    dismiss()
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.remindLater) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
    }

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
