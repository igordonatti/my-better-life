import Foundation
import Testing
@testable import MyBetterLifeCore

// MARK: - SemanticVersion

@Suite("SemanticVersion")
struct SemanticVersionTests {
    @Test("Parses v-prefixed, short and pre-release versions")
    func parsing() throws {
        let full = try #require(SemanticVersion("v1.2.3"))
        #expect(full.major == 1 && full.minor == 2 && full.patch == 3)
        #expect(full.description == "1.2.3")

        #expect(SemanticVersion("V1.2.3") == full)
        #expect(SemanticVersion(" 1.2.3 ") == full)
        #expect(SemanticVersion("1.2") == SemanticVersion(major: 1, minor: 2, patch: 0))
        #expect(SemanticVersion("2") == SemanticVersion(major: 2))

        let beta = try #require(SemanticVersion("1.0.0-beta.1"))
        #expect(beta.preRelease == ["beta", "1"])
        #expect(beta.isPreRelease)
        #expect(beta.description == "1.0.0-beta.1")

        #expect(SemanticVersion("1.0.0+42") == SemanticVersion("1.0.0"))
    }

    @Test("Rejects malformed strings", arguments: ["", "v", "abc", "1..2", "1.2.3.4", "1.x.0", "1.0.0-", "-1.0.0"])
    func rejectsInvalid(raw: String) {
        #expect(SemanticVersion(raw) == nil)
    }

    @Test("Compares numerically, not lexicographically")
    func numericComparison() throws {
        let v190 = try #require(SemanticVersion("1.9.0"))
        let v1100 = try #require(SemanticVersion("1.10.0"))
        #expect(v190 < v1100)
        #expect(try #require(SemanticVersion("v2.0.0")) > v1100)
        #expect(try #require(SemanticVersion("1.0.10")) > (try #require(SemanticVersion("1.0.9"))))
        #expect(SemanticVersion("1.0") == SemanticVersion("1.0.0"))
    }

    @Test("Pre-releases sort before the final release")
    func preReleaseOrdering() throws {
        let alpha = try #require(SemanticVersion("1.0.0-alpha"))
        let beta1 = try #require(SemanticVersion("1.0.0-beta.1"))
        let beta2 = try #require(SemanticVersion("1.0.0-beta.2"))
        let beta11 = try #require(SemanticVersion("1.0.0-beta.11"))
        let final = try #require(SemanticVersion("1.0.0"))
        #expect(alpha < beta1)
        #expect(beta1 < beta2)
        #expect(beta2 < beta11)
        #expect(beta11 < final)
        #expect(final < (try #require(SemanticVersion("1.0.1-beta.1"))))
    }
}

// MARK: - LocalUserProfile & AppVersionInfo

@Suite("LocalUserProfile")
@MainActor
struct LocalUserProfileTests {
    @Test("Initials use first + last word, or first two letters of a single word")
    func initials() {
        #expect(LocalUserProfile.initials(for: "Igor Donatti") == "ID")
        #expect(LocalUserProfile.initials(for: "igor da silva donatti") == "ID")
        #expect(LocalUserProfile.initials(for: "Igor") == "IG")
        #expect(LocalUserProfile.initials(for: "  ana  ") == "AN")
        #expect(LocalUserProfile.initials(for: "Z") == "Z")
        #expect(LocalUserProfile.initials(for: "Érica Ômega") == "ÉÔ")
        #expect(LocalUserProfile.initials(for: "   ") == "?")
    }

    @Test("Persists the display name and falls back to the default when emptied")
    func persistence() throws {
        let suite = "mbl.tests.profile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let profile = LocalUserProfile(defaults: defaults)
        #expect(profile.displayName == LocalUserProfile.defaultDisplayName)
        #expect(!LocalUserProfile.defaultDisplayName.isEmpty)

        profile.displayName = "  Maria Clara  "
        #expect(defaults.string(forKey: LocalUserProfile.displayNameKey) == "Maria Clara")
        #expect(profile.initials == "MC")

        let reloaded = LocalUserProfile(defaults: defaults)
        #expect(reloaded.displayName == "Maria Clara")

        reloaded.displayName = ""
        #expect(defaults.string(forKey: LocalUserProfile.displayNameKey) == nil)
        #expect(reloaded.resolvedDisplayName == LocalUserProfile.defaultDisplayName)
        #expect(!reloaded.initials.isEmpty)
    }

    @Test("AppVersionInfo always yields non-empty values")
    func versionInfo() {
        #expect(!AppVersionInfo.shortVersion.isEmpty)
        #expect(!AppVersionInfo.buildNumber.isEmpty)
    }
}

// MARK: - AppUpdateChecker

/// Routes requests to per-URL handlers so suites can run in parallel without sharing state.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [URL: Handler] = [:]
    nonisolated(unsafe) private static var requests: [URL: [URLRequest]] = [:]

    static func register(_ url: URL, handler: @escaping Handler) {
        lock.withLock { handlers[url] = handler }
    }

    static func recordedRequests(for url: URL) -> [URLRequest] {
        lock.withLock { requests[url] ?? [] }
    }

    static func unregister(_ url: URL) {
        lock.withLock {
            handlers[url] = nil
            requests[url] = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let handler = Self.lock.withLock { () -> Handler? in
            Self.requests[url, default: []].append(request)
            return Self.handlers[url]
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("AppUpdateChecker")
@MainActor
struct AppUpdateCheckerTests {
    /// Isolated fixture: unique repository (=> unique endpoint URL) and a throwaway defaults suite.
    struct Fixture {
        let repository: String
        let endpoint: URL
        let defaults: UserDefaults
        let suiteName: String
        let session: URLSession

        init() {
            let id = UUID().uuidString.lowercased()
            repository = "tests/repo-\(id)"
            endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
            suiteName = "mbl.tests.updates.\(id)"
            defaults = UserDefaults(suiteName: suiteName)!
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubURLProtocol.self]
            session = URLSession(configuration: config)
        }

        @MainActor
        func makeChecker(currentVersion: String) -> AppUpdateChecker {
            AppUpdateChecker(
                currentVersion: currentVersion,
                repository: repository,
                session: session,
                defaults: defaults
            )
        }

        func respond(_ handler: @escaping StubURLProtocol.Handler) {
            StubURLProtocol.register(endpoint, handler: handler)
        }

        func tearDown() {
            StubURLProtocol.unregister(endpoint)
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    nonisolated static func releaseJSON(
        tag: String,
        assets: [(name: String, url: String)] = [],
        body: String = "## Novidades\n- Melhorias"
    ) -> Data {
        let assetObjects = assets.map { ["name": $0.name, "browser_download_url": $0.url] }
        let object: [String: Any] = [
            "tag_name": tag,
            "name": "My Better Life \(tag)",
            "body": body,
            "html_url": "https://github.com/igordonatti/my-better-life/releases/tag/\(tag)",
            "published_at": "2026-11-20T12:00:00Z",
            "draft": false,
            "prerelease": false,
            "assets": assetObjects
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    nonisolated static func http(_ request: URLRequest, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }

    @Test("Default endpoint targets the public repository")
    func defaultEndpoint() {
        let checker = AppUpdateChecker(currentVersion: "1.0.0")
        #expect(checker.repository == "igordonatti/my-better-life")
        #expect(checker.endpoint.absoluteString == "https://api.github.com/repos/igordonatti/my-better-life/releases/latest")
    }

    @Test("Detects a newer release, sends GitHub headers and prefers the .dmg asset")
    func newerReleaseWithDMG() async throws {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            let data = Self.releaseJSON(tag: "v1.2.0", assets: [
                ("MyBetterLife-v1.2.0-source.tar.gz", "https://example.com/src.tar.gz"),
                ("MyBetterLife-v1.2.0-macOS.zip", "https://example.com/app.zip"),
                ("MyBetterLife-v1.2.0-macOS.dmg", "https://example.com/app.dmg")
            ])
            return (Self.http(request, status: 200, headers: ["ETag": "\"abc\""]), data)
        }

        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: true)

        let release = try #require(checker.availableUpdate)
        #expect(release.versionString == "1.2.0")
        #expect(release.tagName == "v1.2.0")
        #expect(release.id == "v1.2.0")
        #expect(release.downloadURL.absoluteString == "https://example.com/app.dmg")
        #expect(release.isDirectInstaller)
        #expect(release.publishedAt != nil)
        #expect(checker.state == .updateAvailable(release))
        #expect(checker.pendingUpdateForBadge == release)
        #expect(checker.lastCheckedAt != nil)

        let sent = try #require(StubURLProtocol.recordedRequests(for: fx.endpoint).first)
        #expect(sent.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(sent.value(forHTTPHeaderField: "User-Agent") == "MyBetterLife/1.0.0")
        #expect(sent.value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test("Falls back to .zip, then to the release page")
    func assetFallbacks() async throws {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "1.1.0", assets: [
                ("notes.txt", "https://example.com/notes.txt"),
                ("MyBetterLife.zip", "https://example.com/app.zip")
            ]))
        }
        let zipChecker = fx.makeChecker(currentVersion: "1.0.0")
        await zipChecker.checkForUpdates(manual: true)
        #expect(zipChecker.availableUpdate?.downloadURL.absoluteString == "https://example.com/app.zip")
        #expect(zipChecker.availableUpdate?.isDirectInstaller == true)

        let fx2 = Fixture()
        defer { fx2.tearDown() }
        fx2.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "1.1.0"))
        }
        let pageChecker = fx2.makeChecker(currentVersion: "1.0.0")
        await pageChecker.checkForUpdates(manual: true)
        let release = try #require(pageChecker.availableUpdate)
        #expect(release.downloadURL == release.releasePageURL)
        #expect(release.downloadURL.absoluteString.hasSuffix("/releases/tag/1.1.0"))
        #expect(!release.isDirectInstaller)
    }

    @Test("Same or older remote version reports up to date with a friendly message")
    func upToDate() async {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "v1.0.0"))
        }
        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: true)
        #expect(checker.state == .upToDate)
        #expect(checker.availableUpdate == nil)
        #expect(checker.pendingUpdateForBadge == nil)
        #expect(checker.statusMessage == "Você já está na versão mais recente.")

        let newer = fx.makeChecker(currentVersion: "1.10.0")
        fx.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "v1.9.0"))
        }
        await newer.checkForUpdates(manual: true)
        #expect(newer.availableUpdate == nil)
    }

    @Test("ETag 304 reuses the cached release across launches")
    func etagCacheReuse() async throws {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            if request.value(forHTTPHeaderField: "If-None-Match") == "W/\"etag-1\"" {
                return (Self.http(request, status: 304, headers: ["ETag": "W/\"etag-1\""]), Data())
            }
            let data = Self.releaseJSON(tag: "v2.0.0", assets: [("App.dmg", "https://example.com/App.dmg")])
            return (Self.http(request, status: 200, headers: ["ETag": "W/\"etag-1\""]), data)
        }

        let first = fx.makeChecker(currentVersion: "1.0.0")
        await first.checkForUpdates(manual: false)
        let original = try #require(first.availableUpdate)

        // Simulated relaunch: a fresh checker restores the cache before any network call.
        let second = fx.makeChecker(currentVersion: "1.0.0")
        #expect(second.availableUpdate == original)
        #expect(second.state == .updateAvailable(original))

        await second.checkForUpdates(manual: true)
        let requests = StubURLProtocol.recordedRequests(for: fx.endpoint)
        #expect(requests.count == 2)
        #expect(requests.last?.value(forHTTPHeaderField: "If-None-Match") == "W/\"etag-1\"")
        #expect(second.availableUpdate == original)
        #expect(second.state == .updateAvailable(original))
    }

    @Test("Skipping a version hides the badge but keeps it in Settings; a newer version re-shows it")
    func skipVersion() async throws {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "v1.1.0"))
        }
        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: false)
        #expect(checker.pendingUpdateForBadge?.versionString == "1.1.0")

        checker.skipVersion("1.1.0")
        #expect(checker.pendingUpdateForBadge == nil)
        #expect(checker.availableUpdate?.versionString == "1.1.0")
        #expect(fx.makeChecker(currentVersion: "1.0.0").skippedVersion == "1.1.0")

        fx.respond { request in
            (Self.http(request, status: 200), Self.releaseJSON(tag: "v1.2.0"))
        }
        await checker.checkForUpdates(manual: false)
        #expect(checker.pendingUpdateForBadge?.versionString == "1.2.0")

        checker.skipVersion("1.2.0")
        #expect(checker.pendingUpdateForBadge == nil)
        checker.clearSkippedVersion()
        #expect(checker.pendingUpdateForBadge?.versionString == "1.2.0")
        #expect(fx.makeChecker(currentVersion: "1.0.0").skippedVersion == nil)
    }

    @Test("Automatic checks fail silently on 404 and offline; manual checks explain")
    func silentFailures() async {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 404), Data("{\"message\":\"Not Found\"}".utf8))
        }
        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: false)
        #expect(checker.state == .idle)
        #expect(checker.availableUpdate == nil)

        await checker.checkForUpdates(manual: true)
        #expect(checker.state == .upToDate)

        fx.respond { _ in throw URLError(.notConnectedToInternet) }
        await checker.checkForUpdates(manual: false)
        #expect(checker.state == .upToDate)

        let offline = fx.makeChecker(currentVersion: "1.0.0")
        await offline.checkForUpdates(manual: false)
        #expect(offline.state == .idle)

        await offline.checkForUpdates(manual: true)
        guard case .failed(let message) = offline.state else {
            Issue.record("Expected a failed state, got \(offline.state)")
            return
        }
        #expect(message.contains("Sem conexão"))
    }

    @Test("Offline automatic check keeps advertising a cached update")
    func offlineKeepsCachedUpdate() async throws {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 200, headers: ["ETag": "\"x\""]), Self.releaseJSON(tag: "v3.0.0"))
        }
        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: false)
        let release = try #require(checker.availableUpdate)

        fx.respond { _ in throw URLError(.notConnectedToInternet) }
        await checker.checkForUpdates(manual: false)
        #expect(checker.state == .updateAvailable(release))
        #expect(checker.pendingUpdateForBadge == release)
    }

    @Test("Rate limiting surfaces a friendly error only on manual checks")
    func rateLimited() async {
        let fx = Fixture()
        defer { fx.tearDown() }
        fx.respond { request in
            (Self.http(request, status: 403), Data())
        }
        let checker = fx.makeChecker(currentVersion: "1.0.0")
        await checker.checkForUpdates(manual: false)
        #expect(checker.state == .idle)
        await checker.checkForUpdates(manual: true)
        if case .failed(let message) = checker.state {
            #expect(message.contains("GitHub"))
        } else {
            Issue.record("Expected failed state")
        }
    }
}
