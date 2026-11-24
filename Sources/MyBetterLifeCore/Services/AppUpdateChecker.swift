import Foundation
import Observation

// MARK: - Semantic Version

/// Minimal SemVer value: `"v1.2.3"`, `"1.2.3"`, `"1.2"`, `"1.0.0-beta.1"`, `"1.0.0+42"`.
/// Leading `v`/`V` and build metadata are ignored; a pre-release sorts before its final release.
public struct SemanticVersion: Comparable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// Dot-separated pre-release identifiers (`["beta", "1"]`), empty for final releases.
    public let preRelease: [String]

    public init(major: Int, minor: Int = 0, patch: Int = 0, preRelease: [String] = []) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
    }

    public init?(_ rawValue: String) {
        var text = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" {
            text.removeFirst()
        }
        // Build metadata never affects precedence.
        if let plus = text.firstIndex(of: "+") {
            text = String(text[..<plus])
        }
        var preRelease: [String] = []
        if let dash = text.firstIndex(of: "-") {
            let suffix = text[text.index(after: dash)...]
            preRelease = suffix.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !preRelease.isEmpty, !preRelease.contains(where: \.isEmpty) else { return nil }
            text = String(text[..<dash])
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty,
                  part.allSatisfy(\.isASCIIDigit),
                  let value = Int(part) else { return nil }
            numbers.append(value)
        }
        while numbers.count < 3 { numbers.append(0) }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2], preRelease: preRelease)
    }

    public var isPreRelease: Bool { !preRelease.isEmpty }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return preRelease.isEmpty ? core : "\(core)-\(preRelease.joined(separator: "."))"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return comparePreRelease(lhs.preRelease, rhs.preRelease) == .orderedAscending
    }

    private static func comparePreRelease(_ lhs: [String], _ rhs: [String]) -> ComparisonResult {
        switch (lhs.isEmpty, rhs.isEmpty) {
        case (true, true): return .orderedSame
        case (true, false): return .orderedDescending
        case (false, true): return .orderedAscending
        case (false, false): break
        }
        for (a, b) in zip(lhs, rhs) where a != b {
            switch (Int(a), Int(b)) {
            case let (x?, y?): return x < y ? .orderedAscending : .orderedDescending
            case (.some, nil): return .orderedAscending
            case (nil, .some): return .orderedDescending
            case (nil, nil): return a < b ? .orderedAscending : .orderedDescending
            }
        }
        if lhs.count == rhs.count { return .orderedSame }
        return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

// MARK: - Release Info

/// A GitHub release normalized for the in-app update UI.
public struct AppReleaseInfo: Equatable, Codable, Sendable, Identifiable {
    public var id: String { tagName }
    public let tagName: String
    /// Tag without the leading `v`, e.g. "1.2.0".
    public let versionString: String
    public let title: String
    public let notes: String
    /// Best direct download (`.dmg`, then `.zip`), or the release page as a fallback.
    public let downloadURL: URL
    public let releasePageURL: URL
    public let publishedAt: Date?
    /// `true` when `downloadURL` points at a downloadable asset rather than the release page.
    public let isDirectInstaller: Bool

    public init(
        tagName: String,
        versionString: String,
        title: String,
        notes: String,
        downloadURL: URL,
        releasePageURL: URL,
        publishedAt: Date?,
        isDirectInstaller: Bool
    ) {
        self.tagName = tagName
        self.versionString = versionString
        self.title = title
        self.notes = notes
        self.downloadURL = downloadURL
        self.releasePageURL = releasePageURL
        self.publishedAt = publishedAt
        self.isDirectInstaller = isDirectInstaller
    }

    public var semanticVersion: SemanticVersion? { SemanticVersion(versionString) }

    private enum CodingKeys: String, CodingKey {
        case tagName, versionString, title, notes, downloadURL, releasePageURL, publishedAt, isDirectInstaller
    }
}

/// Raw subset of `GET /repos/{owner}/{repo}/releases/latest`.
struct GitHubReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        htmlURL = try container.decode(URL.self, forKey: .htmlURL)
        publishedAt = try? container.decodeIfPresent(Date.self, forKey: .publishedAt)
        assets = (try? container.decodeIfPresent([Asset].self, forKey: .assets)) ?? []
    }

    func toReleaseInfo() -> AppReleaseInfo {
        let version = Self.stripVersionPrefix(tagName)
        let asset = Self.bestAsset(in: assets)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AppReleaseInfo(
            tagName: tagName,
            versionString: version,
            title: trimmedName.isEmpty ? "My Better Life v\(version)" : trimmedName,
            notes: body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            downloadURL: asset?.browserDownloadURL ?? htmlURL,
            releasePageURL: htmlURL,
            publishedAt: publishedAt,
            isDirectInstaller: asset != nil
        )
    }

    static func stripVersionPrefix(_ tag: String) -> String {
        var text = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        return text
    }

    /// Prefers `.dmg`, then `.zip`; among equals, names mentioning macOS win.
    static func bestAsset(in assets: [Asset]) -> Asset? {
        func score(_ asset: Asset) -> Int? {
            let name = asset.name.lowercased()
            let base: Int
            if name.hasSuffix(".dmg") {
                base = 20
            } else if name.hasSuffix(".zip") {
                base = 10
            } else {
                return nil
            }
            let macBonus = (name.contains("macos") || name.contains("mac")) ? 1 : 0
            return base + macBonus
        }
        var best: (asset: Asset, score: Int)?
        for asset in assets {
            guard let value = score(asset) else { continue }
            if best == nil || value > best!.score {
                best = (asset, value)
            }
        }
        return best?.asset
    }
}

// MARK: - Update Checker

public enum AppUpdateCheckState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(AppReleaseInfo)
    case failed(String)
}

/// Checks GitHub Releases for a newer version.
///
/// - Uses `If-None-Match` with the persisted ETag: a `304 Not Modified` reuses the cached release
///   and does not count against GitHub's unauthenticated rate limit.
/// - Automatic checks never surface errors (offline, 404, rate limit); manual checks do.
@Observable
@MainActor
public final class AppUpdateChecker {
    public static let defaultRepository = "igordonatti/my-better-life"

    enum DefaultsKey {
        static let etag = "mbl.updates.etag"
        static let cachedRelease = "mbl.updates.cachedRelease"
        static let skippedVersion = "mbl.updates.skippedVersion"
        static let lastCheckedAt = "mbl.updates.lastCheckedAt"
    }

    public private(set) var state: AppUpdateCheckState = .idle
    public private(set) var lastCheckedAt: Date?
    /// Most recent release known (fresh or from the ETag cache), regardless of version.
    public private(set) var latestRelease: AppReleaseInfo?
    public private(set) var skippedVersion: String?

    public let currentVersion: String
    public let repository: String
    public let endpoint: URL

    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let launchDelay: Duration
    @ObservationIgnored private let automaticCheckInterval: Duration
    @ObservationIgnored private var automaticTask: Task<Void, Never>?
    @ObservationIgnored private var isRequestInFlight = false

    public init(
        currentVersion: String = AppVersionInfo.shortVersion,
        repository: String = AppUpdateChecker.defaultRepository,
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        launchDelay: Duration = .seconds(4),
        automaticCheckInterval: Duration = .seconds(6 * 60 * 60)
    ) {
        self.currentVersion = currentVersion
        self.repository = repository
        // Falls back to the default repository URL if a malformed slug is injected.
        self.endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")
            ?? URL(string: "https://api.github.com/repos/\(AppUpdateChecker.defaultRepository)/releases/latest")!
        self.session = session
        self.defaults = defaults
        self.launchDelay = launchDelay
        self.automaticCheckInterval = automaticCheckInterval

        skippedVersion = defaults.string(forKey: DefaultsKey.skippedVersion)
        lastCheckedAt = defaults.object(forKey: DefaultsKey.lastCheckedAt) as? Date
        if let data = defaults.data(forKey: DefaultsKey.cachedRelease) {
            latestRelease = try? JSONDecoder().decode(AppReleaseInfo.self, from: data)
        }
        // Show a cached pending update right away, even before the first network check.
        if let update = availableUpdate {
            state = .updateAvailable(update)
        }
    }

    // MARK: Derived state

    /// Release newer than the running app (still returned if the user skipped it).
    public var availableUpdate: AppReleaseInfo? {
        guard let release = latestRelease, isNewer(release) else { return nil }
        return release
    }

    /// Release to advertise in the sidebar badge: newer AND not skipped by the user.
    public var pendingUpdateForBadge: AppReleaseInfo? {
        guard let release = availableUpdate, release.versionString != skippedVersion else { return nil }
        return release
    }

    public var isChecking: Bool { state == .checking }

    /// Friendly Portuguese status line for the settings sheet.
    public var statusMessage: String {
        switch state {
        case .idle:
            return "Verificação automática ativada."
        case .checking:
            return "Verificando atualizações…"
        case .upToDate:
            return "Você já está na versão mais recente."
        case .updateAvailable(let release):
            return "A versão v\(release.versionString) está disponível."
        case .failed(let message):
            return message
        }
    }

    // MARK: Skip

    public func skipVersion(_ version: String) {
        skippedVersion = version
        defaults.set(version, forKey: DefaultsKey.skippedVersion)
    }

    public func clearSkippedVersion() {
        skippedVersion = nil
        defaults.removeObject(forKey: DefaultsKey.skippedVersion)
    }

    // MARK: Scheduling

    /// Checks a few seconds after launch and then every 6 hours. Idempotent.
    public func startAutomaticChecks() {
        guard automaticTask == nil else { return }
        let launchDelay = launchDelay
        let interval = automaticCheckInterval
        automaticTask = Task { [weak self] in
            do { try await Task.sleep(for: launchDelay) } catch { return }
            while !Task.isCancelled, self != nil {
                await self?.checkForUpdates(manual: false)
                do { try await Task.sleep(for: interval) } catch { return }
            }
        }
    }

    public func stopAutomaticChecks() {
        automaticTask?.cancel()
        automaticTask = nil
    }

    // MARK: Network check

    public func checkForUpdates(manual: Bool) async {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        if manual {
            state = .checking
        }

        let request = makeRequest()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            finishWithFailure(manual: manual, message: Self.message(for: error))
            return
        }

        guard let http = response as? HTTPURLResponse else {
            finishWithFailure(manual: manual, message: "Resposta inesperada do GitHub. Tente novamente mais tarde.")
            return
        }

        switch http.statusCode {
        case 200:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(GitHubReleasePayload.self, from: data)
                let release = payload.toReleaseInfo()
                cache(release: release, etag: http.value(forHTTPHeaderField: "ETag"))
                finishWithRelease(release)
            } catch {
                finishWithFailure(manual: manual, message: "Não foi possível ler as informações da nova versão.")
            }
        case 304:
            if let cached = latestRelease {
                finishWithRelease(cached)
            } else {
                // ETag without a cached body: drop it so the next request fetches the full release.
                defaults.removeObject(forKey: DefaultsKey.etag)
                finishWithFailure(manual: manual, message: "Não foi possível verificar atualizações. Tente novamente.")
            }
        case 404:
            // No published release yet: nothing newer than the running build.
            if manual {
                markChecked()
                state = .upToDate
            } else {
                finishWithFailure(manual: false, message: "")
            }
        case 403, 429:
            finishWithFailure(manual: manual, message: "O GitHub limitou temporariamente as verificações. Tente novamente mais tarde.")
        default:
            finishWithFailure(manual: manual, message: "Não foi possível verificar atualizações (HTTP \(http.statusCode)).")
        }
    }

    // MARK: Internals

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        // We manage ETag ourselves; bypass URLCache so a 304 reaches us untouched.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("MyBetterLife/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if latestRelease != nil, let etag = defaults.string(forKey: DefaultsKey.etag), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        return request
    }

    private func cache(release: AppReleaseInfo, etag: String?) {
        latestRelease = release
        if let data = try? JSONEncoder().encode(release) {
            defaults.set(data, forKey: DefaultsKey.cachedRelease)
        }
        if let etag, !etag.isEmpty {
            defaults.set(etag, forKey: DefaultsKey.etag)
        } else {
            defaults.removeObject(forKey: DefaultsKey.etag)
        }
    }

    private func finishWithRelease(_ release: AppReleaseInfo) {
        markChecked()
        state = isNewer(release) ? .updateAvailable(release) : .upToDate
    }

    private func finishWithFailure(manual: Bool, message: String) {
        if manual {
            state = .failed(message)
        } else if let update = availableUpdate {
            // Silent: keep advertising what we already know from the cache.
            state = .updateAvailable(update)
        } else if case .upToDate = state {
            // Keep the previous successful result.
        } else {
            state = .idle
        }
    }

    private func markChecked() {
        let now = Date()
        lastCheckedAt = now
        defaults.set(now, forKey: DefaultsKey.lastCheckedAt)
    }

    private func isNewer(_ release: AppReleaseInfo) -> Bool {
        guard let remote = SemanticVersion(release.versionString),
              let local = SemanticVersion(currentVersion) else { return false }
        return remote > local
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Sem conexão com a internet. Verifique sua rede e tente novamente."
            case .timedOut:
                return "O GitHub demorou para responder. Tente novamente em instantes."
            default:
                break
            }
        }
        return "Não foi possível verificar atualizações agora. Tente novamente mais tarde."
    }
}
