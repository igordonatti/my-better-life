import Foundation
import Observation

/// Local-only user profile (no account, no login). Persists the display name in `UserDefaults`.
@Observable
@MainActor
public final class LocalUserProfile {
    public static let displayNameKey = "mbl.profile.displayName"
    public static let fallbackDisplayName = "Meu Perfil"

    /// Raw editable name (bound to the settings `TextField`). May be temporarily empty while editing.
    public var displayName: String {
        didSet { persistDisplayName() }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.displayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty {
            displayName = stored
        } else {
            displayName = Self.defaultDisplayName
        }
    }

    /// Name to show in the UI; falls back to the system/default name when the field is empty.
    public var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultDisplayName : trimmed
    }

    /// "Igor Donatti" -> "ID"; "Igor" -> "IG".
    public var initials: String {
        Self.initials(for: resolvedDisplayName)
    }

    /// Default name: macOS account full name when available, otherwise "Meu Perfil".
    public static var defaultDisplayName: String {
        #if os(macOS)
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? fallbackDisplayName : fullName
        #else
        return fallbackDisplayName
        #endif
    }

    public nonisolated static func initials(for name: String) -> String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = words.first else { return "?" }
        if words.count >= 2, let last = words.last, let a = first.first, let b = last.first {
            return (String(a) + String(b)).uppercased()
        }
        return String(first.prefix(2)).uppercased()
    }

    private func persistDisplayName() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Empty name means "use the default" on the next launch.
            defaults.removeObject(forKey: Self.displayNameKey)
        } else {
            defaults.set(trimmed, forKey: Self.displayNameKey)
        }
    }
}

/// Version metadata read from the running bundle's `Info.plist`.
public enum AppVersionInfo {
    public static let fallbackShortVersion = "1.0.0"
    public static let fallbackBuildNumber = "1"

    /// Marketing version (`CFBundleShortVersionString`), e.g. "1.0.0".
    public static var shortVersion: String {
        infoString("CFBundleShortVersionString") ?? fallbackShortVersion
    }

    /// Build number (`CFBundleVersion`), e.g. "1".
    public static var buildNumber: String {
        infoString("CFBundleVersion") ?? fallbackBuildNumber
    }

    /// "1.0.0 (1)"
    public static var fullVersion: String {
        "\(shortVersion) (\(buildNumber))"
    }

    private static func infoString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
