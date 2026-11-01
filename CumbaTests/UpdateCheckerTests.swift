import Foundation
import Testing

@testable import Cumba

struct UpdateCheckerTests {
  @Test(arguments: [
    ("1.0.0", "0.9.9", true), ("1.0.0", "1.0.0", false), ("1.10.0", "1.9.0", true),
    ("1.0.0", "1.0.0-rc1", true), ("1.0.0-rc2", "1.0.0-rc1", true), ("0.7.0", "0.7", false),
    ("2", "1.9.9", true), ("1.0.0", "", true), ("", "1.0.0", false), ("-", "", false),
  ])
  func comparesVersions(newer: String, older: String, expected: Bool) {
    #expect(UpdateChecker.isVersion(newer, newerThan: older) == expected)
  }

  @Test func picksTheNewestAllowedRelease() throws {
    let json = """
      [
        { "tag_name": "v1.1.0-beta", "html_url": "https://github.com/muazfurkan/Cumba/releases/tag/v1.1.0-beta", "prerelease": true, "draft": false },
        { "tag_name": "v1.0.1", "html_url": "https://github.com/muazfurkan/Cumba/releases/tag/v1.0.1", "prerelease": false, "draft": false },
        { "tag_name": "v0.9.0", "html_url": "https://github.com/muazfurkan/Cumba/releases/tag/v0.9.0", "prerelease": true },
        { "tag_name": "v9.9.9", "html_url": "https://evil.example/download", "prerelease": false },
        { "tag_name": "v", "html_url": "https://github.com/muazfurkan/Cumba/releases/tag/v", "prerelease": false },
        { "tag_name": "latest", "html_url": "https://github.com/muazfurkan/Cumba/releases/tag/latest", "prerelease": false }
      ]
      """
    let releases = try UpdateChecker.parse(Data(json.utf8))
    #expect(releases.count == 3)
    #expect(
      UpdateChecker.newest(in: releases, than: "1.0.0", includePrereleases: false)?.version
        == "1.0.1")
    #expect(
      UpdateChecker.newest(in: releases, than: "1.0.0", includePrereleases: true)?.version
        == "1.1.0-beta")
    #expect(UpdateChecker.newest(in: releases, than: "1.0.1", includePrereleases: false) == nil)
  }
}

@MainActor
struct DiagnosticsTests {
  @Test func reportHasNoToken() async throws {
    let suite = "DiagnosticsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let center = LiveActivityCenter()
    let server = LocalServer(
      browserHub: BrowserMediaHub(), claude: ClaudeCodeService(liveActivities: center))
    let folder = FileManager.default.temporaryDirectory.appending(path: "diag-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let report = await Diagnostics.report(
      Diagnostics.Sources(
        settings: AppSettings(defaults: defaults),
        themes: ThemeStore(files: ThemeFiles(directory: folder), defaults: defaults),
        layout: LayoutStore(fileURL: folder.appending(path: "layout.json"), knownKinds: []),
        server: server))
    #expect(report.contains("Cumba"))
    #expect(report.contains("macOS"))
    #expect(!report.contains(NSHomeDirectory()))
    for token in [server.hookToken, server.extensionToken] where !token.isEmpty {
      #expect(!report.contains(token))
    }
  }
}
