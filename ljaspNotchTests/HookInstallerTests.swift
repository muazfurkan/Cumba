import Foundation
import Testing

@testable import ljaspNotch

/// Works on a settings.json in a temporary folder; never touches ~/.claude.
struct HookInstallerTests {
  private let folder = FileManager.default.temporaryDirectory
    .appending(path: "HookInstallerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  private let token = String(repeating: "d", count: 64)

  private var installer: HookInstaller {
    HookInstaller(settingsURL: folder.appending(path: "settings.json"))
  }

  private func write(_ text: String) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(text.utf8).write(to: installer.settingsURL)
  }

  private func read() throws -> [String: Any] {
    let data = try Data(contentsOf: installer.settingsURL)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func cleanUp() {
    try? FileManager.default.removeItem(at: folder)
  }

  @Test func installsIntoAMissingFile() throws {
    defer { cleanUp() }
    let plan = try installer.planInstall(port: 47823, token: token)
    #expect(plan.hasChanges)
    #expect(try installer.apply(plan) == nil)
    #expect(try installer.status(port: 47823, token: token) == .installed)
    let hooks = try #require(try read()["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == HookInstaller.events.map(\.name).sorted())
  }

  @Test func keepsOtherSettingsAndHooksAndBacksUp() throws {
    defer { cleanUp() }
    try write(
      """
      {
        "model": "opus",
        "hooks": {
          "Stop": [{ "hooks": [{ "type": "command", "command": "say done" }] }],
          "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "check" }] }]
        }
      }
      """)
    let backup = try installer.apply(try installer.planInstall(port: 47823, token: token))
    #expect(backup?.lastPathComponent.hasPrefix("settings.json.bak-") == true)
    let settings = try read()
    #expect(settings["model"] as? String == "opus")
    let hooks = try #require(settings["hooks"] as? [String: Any])
    #expect((hooks["Stop"] as? [Any])?.count == 2)
    #expect(hooks["PreToolUse"] != nil)
  }

  @Test func installingTwiceChangesNothing() throws {
    defer { cleanUp() }
    try installer.apply(try installer.planInstall(port: 47823, token: token))
    #expect(!(try installer.planInstall(port: 47823, token: token)).hasChanges)
  }

  @Test func newPortOrTokenMakesItOutdatedAndUpdateReplacesEntries() throws {
    defer { cleanUp() }
    try installer.apply(try installer.planInstall(port: 47823, token: token))
    #expect(try installer.status(port: 50000, token: token) == .outdated)
    try installer.apply(try installer.planInstall(port: 50000, token: token))
    #expect(try installer.status(port: 50000, token: token) == .installed)
    let stop = try #require((try read()["hooks"] as? [String: Any])?["Stop"] as? [Any])
    #expect(stop.count == 1)
  }

  @Test func uninstallRemovesOnlyOurEntries() throws {
    defer { cleanUp() }
    try write(
      #"{ "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": "say done" }] }] } }"#)
    try installer.apply(try installer.planInstall(port: 47823, token: token))
    try installer.apply(try installer.planUninstall())
    let hooks = try #require(try read()["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == ["Stop"])
    #expect(try installer.status(port: 47823, token: token) == .notInstalled)
  }

  @Test func invalidJSONIsNeverOverwritten() throws {
    defer { cleanUp() }
    try write("{ not json")
    #expect(throws: HookInstaller.Failure.unreadable) {
      try installer.planInstall(port: 47823, token: token)
    }
    #expect(
      String(decoding: try Data(contentsOf: installer.settingsURL), as: UTF8.self) == "{ not json")
  }

  @Test func changesAfterReviewAreNotOverwritten() throws {
    defer { cleanUp() }
    try write(#"{ "model": "opus" }"#)
    let plan = try installer.planInstall(port: 47823, token: token)
    try write(#"{ "model": "sonnet" }"#)
    #expect(throws: HookInstaller.Failure.changedSinceReview) { try installer.apply(plan) }
  }

  @Test func allowlistWithoutOurAddressIsDetected() {
    let url = HookInstaller.hookURL(port: 47823)
    #expect(!HookInstaller.isBlocked(url: url, in: [:]))
    #expect(HookInstaller.isBlocked(url: url, in: ["allowedHttpHookUrls": []]))
    #expect(
      HookInstaller.isBlocked(url: url, in: ["allowedHttpHookUrls": ["https://hooks.example/*"]]))
    #expect(!HookInstaller.isBlocked(url: url, in: ["allowedHttpHookUrls": ["http://127.0.0.1:*"]]))
  }

  @Test func onlyLoopbackHookEntriesCountAsOurs() {
    #expect(HookInstaller.isOurs(["type": "http", "url": "http://127.0.0.1:47823/claude/hook"]))
    #expect(HookInstaller.isOurs(["type": "http", "url": "http://localhost:1234/claude/hook"]))
    #expect(!HookInstaller.isOurs(["type": "http", "url": "https://example.com/claude/hook"]))
    #expect(!HookInstaller.isOurs(["type": "command", "command": "x"]))
  }

  @Test func diffShowsAddedAndRemovedLines() {
    let lines = DiffLine.lines(from: "a\nb\nc", to: "a\nx\nc")
    #expect(lines.map(\.kind) == [.context, .removed, .added, .context])
  }
}
