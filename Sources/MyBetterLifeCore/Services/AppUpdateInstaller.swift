import CryptoKit
import Foundation
import Observation

#if os(macOS)
import AppKit
#endif

// MARK: - SHA-256 Checksum Verifier

/// Pure, streaming SHA-256 checksum utility for verifying downloaded GitHub Release artifacts
/// against `SHA256SUMS.txt` without loading entire installers into memory.
public enum SHA256ChecksumVerifier {
    /// Parses a `shasum -a 256` file and returns the lowercase 64-character hex digest for `fileName`.
    public static func parseExpectedHash(forFileName fileName: String, from content: String) -> String? {
        let targetName = (fileName as NSString).lastPathComponent.lowercased()
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            // Standard `shasum -a 256` format: `<64-hex>  <filename>` or `<64-hex> *<filename>`
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 2 else { continue }

            let hashCandidate = String(parts[0]).lowercased()
            guard hashCandidate.count == 64,
                  hashCandidate.allSatisfy({ $0.isHexDigit }) else { continue }

            var listedName = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if listedName.hasPrefix("*") {
                listedName.removeFirst()
            }
            let listedBaseName = (listedName as NSString).lastPathComponent.lowercased()
            if listedBaseName == targetName {
                return hashCandidate
            }
        }
        return nil
    }

    /// Computes the lowercase hex SHA-256 digest of a file on disk using streaming chunks.
    public static func sha256Hex(of fileURL: URL, chunkSize: Int = 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Verifies that `fileURL` matches `expectedHash` (case-insensitive 64-char hex).
    public static func verify(fileURL: URL, expectedHash: String) throws -> Bool {
        let actual = try sha256Hex(of: fileURL)
        return actual.lowercased() == expectedHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Installer State & Errors

public enum AppUpdateInstallState: Equatable, Sendable {
    case idle
    case downloading(progress: Double?)
    case verifying
    case installing
    case relaunching
    case failed(String)

    public var isBusy: Bool {
        switch self {
        case .downloading, .verifying, .installing, .relaunching:
            return true
        case .idle, .failed:
            return false
        }
    }
}

public enum AppUpdateInstallError: LocalizedError, Sendable {
    case notRunningFromAppBundle
    case destinationNotWritable(String)
    case downloadFailed(String)
    case checksumMismatch
    case mountFailed(String)
    case appBundleNotFoundInArchive
    case invalidBundleIdentifier(expected: String, found: String?)
    case stagingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "A instalação automática só funciona quando o app é aberto pelo pacote .app instalado (ex.: em /Applications)."
        case .destinationNotWritable(let dir):
            return "Sem permissão de escrita em \(dir). Baixe o .dmg manualmente e arraste para Aplicativos."
        case .downloadFailed(let detail):
            return "Não foi possível baixar a atualização: \(detail)"
        case .checksumMismatch:
            return "A verificação de integridade (SHA-256) falhou. A atualização foi cancelada por segurança."
        case .mountFailed(let detail):
            return "Não foi possível abrir o arquivo da atualização: \(detail)"
        case .appBundleNotFoundInArchive:
            return "Nenhum aplicativo .app foi encontrado dentro da imagem baixada."
        case .invalidBundleIdentifier(let expected, let found):
            return "O pacote baixado não corresponde ao My Better Life (esperado \(expected), encontrado \(found ?? "desconhecido"))."
        case .stagingFailed(let detail):
            return "Não foi possível preparar a nova versão: \(detail)"
        }
    }
}

// MARK: - macOS One-Click Self-Updater

#if os(macOS)
/// Downloads, SHA-256 verifies, stages, atomically swaps and relaunches the macOS `.app` bundle
/// in place without requiring an Apple Developer ID or external updater framework.
@Observable
@MainActor
public final class AppUpdateInstaller {
    public private(set) var state: AppUpdateInstallState = .idle

    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var activeDownloadDelegate: DownloadProgressDelegate?
    @ObservationIgnored private let expectedBundleIdentifier: String

    public init(expectedBundleIdentifier: String = "com.igordonatti.mybetterlife") {
        self.expectedBundleIdentifier = expectedBundleIdentifier
    }

    /// `true` when the running process is a real `.app` bundle inside a writable folder (e.g. `/Applications`).
    public var canInstallInPlace: Bool {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension.lowercased() == "app" else { return false }
        let parentDir = bundleURL.deletingLastPathComponent().path
        return FileManager.default.isWritableFile(atPath: parentDir)
    }

    public func installAndRelaunch(_ release: AppReleaseInfo) {
        guard !state.isBusy else { return }

        let targetAppURL = Bundle.main.bundleURL
        guard targetAppURL.pathExtension.lowercased() == "app" else {
            state = .failed(AppUpdateInstallError.notRunningFromAppBundle.localizedDescription)
            return
        }

        let parentPath = targetAppURL.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: parentPath) else {
            state = .failed(AppUpdateInstallError.destinationNotWritable(parentPath).localizedDescription)
            return
        }

        state = .downloading(progress: 0)

        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.performInstall(release: release, targetAppURL: targetAppURL)
        }
    }

    public func cancel() {
        activeDownloadDelegate?.cancel()
        activeDownloadDelegate = nil
        activeTask?.cancel()
        activeTask = nil
        if case .downloading = state {
            state = .idle
        }
    }

    public func reset() {
        guard !state.isBusy else { return }
        state = .idle
    }

    // MARK: - Pipeline

    private func performInstall(release: AppReleaseInfo, targetAppURL: URL) async {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("mbl-update-\(UUID().uuidString)", isDirectory: true)
        var shouldCleanupWorkDir = true

        defer {
            activeDownloadDelegate = nil
            if shouldCleanupWorkDir {
                try? fm.removeItem(at: workDir)
            }
        }

        do {
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

            // 1. Download asset with live progress
            let assetFileName = release.assetName ?? release.downloadURL.lastPathComponent
            let downloadedFileURL = workDir.appendingPathComponent(assetFileName.isEmpty ? "update.dmg" : assetFileName)
            try await downloadFile(from: release.downloadURL, to: downloadedFileURL)
            try Task.checkCancellation()

            // 2. Verify SHA-256 against SHA256SUMS.txt when available
            state = .verifying
            if let checksumURL = release.checksumURL, let expectedFileName = release.assetName {
                let (checksumData, checksumResp) = try await URLSession.shared.data(from: checksumURL)
                if let http = checksumResp as? HTTPURLResponse, http.statusCode == 200,
                   let content = String(data: checksumData, encoding: .utf8),
                   let expectedHash = SHA256ChecksumVerifier.parseExpectedHash(forFileName: expectedFileName, from: content) {
                    let isValid = try await Task.detached(priority: .userInitiated) {
                        try SHA256ChecksumVerifier.verify(fileURL: downloadedFileURL, expectedHash: expectedHash)
                    }.value
                    guard isValid else {
                        throw AppUpdateInstallError.checksumMismatch
                    }
                }
            }
            try Task.checkCancellation()

            // 3. Extract & stage the new .app bundle (background queue so UI stays responsive)
            state = .installing
            let stagedAppURL = workDir.appendingPathComponent("My Better Life.app", isDirectory: true)
            let expectedBundleID = expectedBundleIdentifier
            try await Task.detached(priority: .userInitiated) {
                try Self.extractAndStageApp(
                    archiveURL: downloadedFileURL,
                    workDir: workDir,
                    stagedAppURL: stagedAppURL,
                    expectedBundleID: expectedBundleID
                )
            }.value
            try Task.checkCancellation()

            // 4. Spawn detached atomic swap + relaunch helper, then exit cleanly
            state = .relaunching
            try launchAtomicSwapHelper(
                stagedAppURL: stagedAppURL,
                targetAppURL: targetAppURL,
                workDir: workDir
            )
            // Helper script cleans up `workDir` after swapping.
            shouldCleanupWorkDir = false

            // Short beat so the "Reiniciando…" label renders before termination.
            try? await Task.sleep(for: .milliseconds(250))
            NSApp.terminate(nil)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func downloadFile(from remoteURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = DownloadProgressDelegate(
                destinationURL: destinationURL,
                onProgress: { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = .downloading(progress: fraction)
                    }
                },
                onComplete: { result in
                    continuation.resume(with: result)
                }
            )
            self.activeDownloadDelegate = delegate
            delegate.start(url: remoteURL)
        }
    }

    // MARK: - Extraction & Validation (nonisolated)

    nonisolated private static func extractAndStageApp(
        archiveURL: URL,
        workDir: URL,
        stagedAppURL: URL,
        expectedBundleID: String
    ) throws {
        let fm = FileManager.default
        let ext = archiveURL.pathExtension.lowercased()

        if ext == "dmg" {
            let mountPoint = workDir.appendingPathComponent("mount", isDirectory: true)
            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)

            let attach = try runProcess(
                "/usr/bin/hdiutil",
                arguments: [
                    "attach", archiveURL.path,
                    "-nobrowse",
                    "-readonly",
                    "-noautoopen",
                    "-mountpoint", mountPoint.path
                ]
            )
            guard attach.exitCode == 0 else {
                throw AppUpdateInstallError.mountFailed(attach.stderr.isEmpty ? "hdiutil exit \(attach.exitCode)" : attach.stderr)
            }

            defer {
                _ = try? runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint.path, "-force"])
            }

            guard let sourceApp = findAppBundle(in: mountPoint) else {
                throw AppUpdateInstallError.appBundleNotFoundInArchive
            }

            let copyResult = try runProcess("/usr/bin/ditto", arguments: [sourceApp.path, stagedAppURL.path])
            guard copyResult.exitCode == 0 else {
                throw AppUpdateInstallError.stagingFailed(copyResult.stderr.isEmpty ? "ditto exit \(copyResult.exitCode)" : copyResult.stderr)
            }
        } else if ext == "zip" {
            let extractDir = workDir.appendingPathComponent("unzip", isDirectory: true)
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let unzip = try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, extractDir.path])
            guard unzip.exitCode == 0 else {
                throw AppUpdateInstallError.mountFailed(unzip.stderr.isEmpty ? "ditto exit \(unzip.exitCode)" : unzip.stderr)
            }

            guard let sourceApp = findAppBundle(in: extractDir) else {
                throw AppUpdateInstallError.appBundleNotFoundInArchive
            }

            let copyResult = try runProcess("/usr/bin/ditto", arguments: [sourceApp.path, stagedAppURL.path])
            guard copyResult.exitCode == 0 else {
                throw AppUpdateInstallError.stagingFailed(copyResult.stderr.isEmpty ? "ditto exit \(copyResult.exitCode)" : copyResult.stderr)
            }
        } else {
            throw AppUpdateInstallError.mountFailed("Formato não suportado (.\(ext)).")
        }

        // Strip any quarantine attribute on the freshly staged app and verify its Info.plist
        _ = try? runProcess("/usr/bin/xattr", arguments: ["-dr", "com.apple.quarantine", stagedAppURL.path])
        try validateStagedBundle(at: stagedAppURL, expectedBundleID: expectedBundleID)
    }

    nonisolated private static func findAppBundle(in directory: URL) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return entries.first(where: { $0.pathExtension.lowercased() == "app" })
    }

    nonisolated private static func validateStagedBundle(at appURL: URL, expectedBundleID: String) throws {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
            throw AppUpdateInstallError.stagingFailed("Info.plist ausente no pacote baixado.")
        }

        let foundID = dict["CFBundleIdentifier"] as? String
        guard foundID == expectedBundleID else {
            throw AppUpdateInstallError.invalidBundleIdentifier(expected: expectedBundleID, found: foundID)
        }

        guard let executableName = dict["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            throw AppUpdateInstallError.stagingFailed("Executável não declarado no Info.plist.")
        }

        let execURL = appURL.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard FileManager.default.isExecutableFile(atPath: execURL.path) else {
            throw AppUpdateInstallError.stagingFailed("Executável inválido dentro do novo .app.")
        }
    }

    // MARK: - Detached Atomic Swap Helper

    private func launchAtomicSwapHelper(
        stagedAppURL: URL,
        targetAppURL: URL,
        workDir: URL
    ) throws {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let backupURL = targetAppURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(targetAppURL.lastPathComponent).mbl-backup-\(currentPID)")

        // Safe shell script with positional arguments (zero shell-injection risk) and automatic rollback.
        let script = """
        PID="$1"
        STAGED="$2"
        DEST="$3"
        BACKUP="$4"
        WORKDIR="$5"

        # 1. Wait cleanly for current My Better Life process to finish saving Core Data and exit (up to 15s)
        i=0
        while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 100 ]; do
            sleep 0.15
            i=$((i + 1))
        done

        # 2. Atomic swap with automatic rollback if anything fails
        rm -rf "$BACKUP"
        if [ -e "$DEST" ]; then
            mv "$DEST" "$BACKUP" || exit 1
        fi

        if mv "$STAGED" "$DEST"; then
            rm -rf "$BACKUP"
            rm -rf "$WORKDIR"
            /usr/bin/open "$DEST"
        else
            # Roll back so the user is never left without the app
            if [ -e "$BACKUP" ]; then
                mv "$BACKUP" "$DEST"
            fi
            rm -rf "$WORKDIR"
            exit 1
        fi
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", script, "mbl-updater",
            String(currentPID),
            stagedAppURL.path,
            targetAppURL.path,
            backupURL.path,
            workDir.path
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    nonisolated private static func runProcess(_ executablePath: String, arguments: [String]) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

// MARK: - Streaming Download Delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @Sendable (Double?) -> Void
    private let onComplete: @Sendable (Result<Void, Error>) -> Void

    private let lock = NSLock()
    private var hasCompleted = false
    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    init(
        destinationURL: URL,
        onProgress: @escaping @Sendable (Double?) -> Void,
        onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func start(url: URL) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        lock.withLock {
            self.session = session
            self.task = task
        }
        task.resume()
    }

    func cancel() {
        let (activeTask, activeSession) = lock.withLock { (task, session) }
        activeTask?.cancel()
        activeSession?.invalidateAndCancel()
        finish(with: .failure(CancellationError()))
    }

    private func finish(with result: Result<Void, Error>) {
        let shouldFire: Bool = lock.withLock {
            if hasCompleted { return false }
            hasCompleted = true
            return true
        }
        guard shouldFire else { return }
        let activeSession = lock.withLock { session }
        activeSession?.finishTasksAndInvalidate()
        onComplete(result)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let fraction = min(1.0, max(0.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
            onProgress(fraction)
        } else {
            onProgress(nil)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            finish(with: .failure(AppUpdateInstallError.downloadFailed("HTTP \(http.statusCode)")))
            return
        }

        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)
            finish(with: .success(()))
        } catch {
            finish(with: .failure(AppUpdateInstallError.downloadFailed(error.localizedDescription)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            finish(with: .failure(CancellationError()))
        } else {
            finish(with: .failure(AppUpdateInstallError.downloadFailed(error.localizedDescription)))
        }
    }
}
#endif
