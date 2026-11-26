import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("AppUpdateInstaller & SHA256ChecksumVerifier")
struct AppUpdateInstallerTests {

    @Test("Parses standard shasum -a 256 files with two spaces, single space, or binary asterisk")
    func parsesChecksumManifest() {
        let expectedHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let otherHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        let manifest = """
        # Release checksums
        \(otherHash)  SomeOtherFile.zip
        \(expectedHash.uppercased())  MyBetterLife-v1.1.0-macOS.dmg
        """

        let parsed = SHA256ChecksumVerifier.parseExpectedHash(
            forFileName: "MyBetterLife-v1.1.0-macOS.dmg",
            from: manifest
        )
        #expect(parsed == expectedHash)

        // Binary-mode asterisk prefix (`*filename`)
        let starManifest = "\(expectedHash) *dist/MyBetterLife-v1.1.0-macOS.dmg\n"
        #expect(
            SHA256ChecksumVerifier.parseExpectedHash(forFileName: "MyBetterLife-v1.1.0-macOS.dmg", from: starManifest)
                == expectedHash
        )

        // Missing file returns nil
        #expect(
            SHA256ChecksumVerifier.parseExpectedHash(forFileName: "NonExistent.dmg", from: manifest) == nil
        )
    }

    @Test("Computes and verifies streaming SHA-256 digest of a file on disk")
    func verifiesFileChecksum() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mbl-sha-test-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Known SHA-256 test vector: SHA256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        try Data("abc".utf8).write(to: tempURL)

        let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let actual = try SHA256ChecksumVerifier.sha256Hex(of: tempURL, chunkSize: 2)
        #expect(actual == expected)
        #expect(try SHA256ChecksumVerifier.verify(fileURL: tempURL, expectedHash: expected.uppercased()) == true)
        #expect(try SHA256ChecksumVerifier.verify(fileURL: tempURL, expectedHash: String(repeating: "0", count: 64)) == false)
    }

    @Test("GitHub release payload captures assetName and SHA256SUMS.txt checksumURL")
    func payloadExtractsAssetAndChecksumURL() throws {
        let json = """
        {
          "tag_name": "v1.2.0",
          "name": "My Better Life v1.2.0",
          "body": "Auto update!",
          "html_url": "https://github.com/igordonatti/my-better-life/releases/tag/v1.2.0",
          "published_at": "2026-11-26T20:00:00Z",
          "assets": [
            {
              "name": "MyBetterLife-v1.2.0-macOS.dmg",
              "browser_download_url": "https://github.com/igordonatti/my-better-life/releases/download/v1.2.0/MyBetterLife-v1.2.0-macOS.dmg"
            },
            {
              "name": "SHA256SUMS.txt",
              "browser_download_url": "https://github.com/igordonatti/my-better-life/releases/download/v1.2.0/SHA256SUMS.txt"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(GitHubReleasePayload.self, from: Data(json.utf8))
        let release = payload.toReleaseInfo()

        #expect(release.isDirectInstaller == true)
        #expect(release.assetName == "MyBetterLife-v1.2.0-macOS.dmg")
        #expect(release.checksumURL?.lastPathComponent == "SHA256SUMS.txt")
    }
}
