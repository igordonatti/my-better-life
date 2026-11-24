import SwiftUI
import MyBetterLifeCore

/// Local profile, version/update status and "about" info. No login, no cloud, no paywall.
struct ProfileAndSettingsSheet: View {
    @Bindable var userProfile: LocalUserProfile
    @Bindable var updateChecker: AppUpdateChecker

    @Environment(\.dismiss) private var dismiss
    @State private var isUpdateSheetPresented = false

    private static let repositoryURL = URL(string: "https://github.com/igordonatti/my-better-life")!

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                versionSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle(L10n.profileSettingsTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 560)
        #endif
        .sheet(isPresented: $isUpdateSheetPresented) {
            if let release = updateChecker.availableUpdate {
                UpdateAvailableSheet(release: release, updateChecker: updateChecker)
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                ProfileAvatarView(initials: userProfile.initials, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.profileNameLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L10n.profileNamePlaceholder, text: $userProfile.displayName)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        #endif
                        .accessibilityLabel(L10n.profileNameLabel)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(L10n.profileSectionTitle)
        } footer: {
            Text(L10n.profileLocalFootnote)
        }
    }

    private var versionSection: some View {
        Section(L10n.versionSectionTitle) {
            LabeledContent(L10n.currentVersionLabel) {
                Text("v\(AppVersionInfo.shortVersion)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L10n.lastCheckedLabel) {
                Text(lastCheckedText)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                statusIcon
                Text(updateChecker.statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Button {
                Task { await updateChecker.checkForUpdates(manual: true) }
            } label: {
                HStack(spacing: 8) {
                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(L10n.checkForUpdates)
                }
            }
            .disabled(updateChecker.isChecking)

            if let update = updateChecker.availableUpdate {
                Button {
                    isUpdateSheetPresented = true
                } label: {
                    Label("\(L10n.viewUpdate) v\(update.versionString)", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if updateChecker.skippedVersion == update.versionString {
                    Text(L10n.skippedVersionNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(L10n.aboutSectionTitle) {
            Text(L10n.aboutDescription)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Label(L10n.aboutLicense, systemImage: "checkmark.seal")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link(destination: Self.repositoryURL) {
                Label(L10n.aboutRepositoryLink, systemImage: "arrow.up.right.square")
            }
        }
    }

    // MARK: - Helpers

    private var lastCheckedText: String {
        guard let date = updateChecker.lastCheckedAt else { return L10n.neverChecked }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppTheme.ptBRLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch updateChecker.state {
        case .checking:
            ProgressView().controlSize(.small)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .updateAvailable:
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .idle:
            Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        if case .failed = updateChecker.state { return .orange }
        return .secondary
    }
}

/// Circular initials avatar used by the sidebar card and settings.
struct ProfileAvatarView: View {
    let initials: String
    var size: CGFloat = 30

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .accessibilityHidden(true)
    }
}
