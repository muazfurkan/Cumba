import Foundation
import Testing

@testable import Cumba

/// Works on a settings.json in a temporary folder; never touches ~/.claude.
struct HookInstallerTests {
  private let folder = FileManager.default.temporaryDirectory
    .appending(path: "HookInstallerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  private let token = String(repeating: "d", count: 64)
  private let socket = "/Users/example/Library/Application Support/Cumba/hook.sock"

  private var installer: HookInstaller {
    HookInstaller(settingsURL: folder.appending(path: "settings.json"), socketPath: socket)
  }

  private func write(_ text: String, to name: String = "settings.json") throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(text.utf8).write(to: folder.appending(path: name))
  }

  private func read(_ name: String = "settings.json") throws -> [String: Any] {
    let data = try Data(contentsOf: folder.appending(path: name))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func cleanUp() {
    try? FileManager.default.removeItem(at: folder)
  }

  @Test func installsCommandHooksIntoAMissingFile() throws {
    defer { cleanUp() }
    let plan = try installer.planInstall(token: token)
    #expect(plan.hasChanges)
    #expect(try installer.apply(plan) == nil)
    #expect(try installer.status(token: token) == .installed)
    let hooks = try #require(try read()["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == HookInstaller.events.map(\.name).sorted())
    let entry = try #require(
      ((hooks["PermissionRequest"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?
        .first)
    #expect(entry["type"] as? String == "command")
    #expect(entry["timeout"] as? Int == 300)
    let command = try #require(entry["command"] as? String)
    #expect(command.hasPrefix("/usr/bin/curl -sf --max-time 299 --unix-socket"))
    #expect(command.hasSuffix("|| true"))
  }

  @Test func commandQuotesPathsAndHeaders() {
    let command = HookInstaller.command(
      socketPath: "/tmp/it's here/hook.sock", token: "t", timeout: 2)
    #expect(command.contains(#"--unix-socket '/tmp/it'\''s here/hook.sock'"#))
    #expect(command.contains("--max-time 1 "))
    #expect(command.contains("-H 'X-Cumba-Token: t'"))
  }

  @Test func keepsOtherSettingsAndHooksAndBacksUpPrivately() throws {
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
    let backup = try #require(try installer.apply(try installer.planInstall(token: token)))
    #expect(backup.lastPathComponent.hasPrefix("settings.json.bak-"))
    let attributes = try FileManager.default.attributesOfItem(atPath: backup.path())
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    let settings = try read()
    #expect(settings["model"] as? String == "opus")
    let hooks = try #require(settings["hooks"] as? [String: Any])
    #expect((hooks["Stop"] as? [Any])?.count == 2)
    #expect(hooks["PreToolUse"] != nil)
  }

  @Test func installingTwiceChangesNothing() throws {
    defer { cleanUp() }
    try installer.apply(try installer.planInstall(token: token))
    #expect(!(try installer.planInstall(token: token)).hasChanges)
  }

  @Test func newTokenMakesItOutdatedAndUpdateReplacesEntries() throws {
    defer { cleanUp() }
    try installer.apply(try installer.planInstall(token: token))
    let newToken = String(repeating: "e", count: 64)
    #expect(try installer.status(token: newToken) == .outdated)
    try installer.apply(try installer.planInstall(token: newToken))
    #expect(try installer.status(token: newToken) == .installed)
    let stop = try #require((try read()["hooks"] as? [String: Any])?["Stop"] as? [Any])
    #expect(stop.count == 1)
  }

  @Test func updateReplacesHTTPHooksFromEarlierVersions() throws {
    defer { cleanUp() }
    try write(
      #"{ "hooks": { "Stop": [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "headers": { "X-LjaspNotch-Token": "old" } }] }] } }"#
    )
    #expect(try installer.status(token: token) == .outdated)
    try installer.apply(try installer.planInstall(token: token))
    let stop = try #require((try read()["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])
    #expect(stop.count == 1)
    #expect((stop[0]["hooks"] as? [[String: Any]])?.first?["type"] as? String == "command")
  }

  @Test func updateReplacesHooksUnderTheFormerName() throws {
    defer { cleanUp() }
    let oldSocket = "/Users/example/Library/Application Support/ljaspNotch/hook.sock"
    let oldCommand = HookInstaller.command(socketPath: oldSocket, token: token, timeout: 5)
      .replacingOccurrences(of: RequestGuard.tokenHeader, with: HookInstaller.legacyTokenHeader)
    let settings: [String: Any] = [
      "hooks": ["Stop": [["hooks": [["type": "command", "command": oldCommand, "timeout": 5]]]]]
    ]
    try write(String(decoding: try JSONSerialization.data(withJSONObject: settings), as: UTF8.self))
    #expect(try installer.status(token: token) == .outdated)
    let plan = try installer.planInstall(token: token)
    #expect(!plan.diff.contains { $0.text.contains(token) })
    try installer.apply(plan)
    #expect(try installer.status(token: token) == .installed)
    let stop = try #require((try read()["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])
    #expect(stop.count == 1)
    let command = try #require((stop[0]["hooks"] as? [[String: Any]])?.first?["command"] as? String)
    #expect(command.contains("Cumba/hook.sock"))
    #expect(!command.contains("ljaspNotch"))
  }

  @Test func otherToolsOnTheSamePathAreNotOurs() {
    #expect(!HookInstaller.isOurs(["type": "http", "url": "http://127.0.0.1:9000/claude/hook"]))
    #expect(
      !HookInstaller.isOurs(["type": "command", "command": "curl http://localhost/claude/hook"]))
    #expect(!HookInstaller.isOurs(["type": "http", "url": "https://example.com/claude/hook"]))
    #expect(
      HookInstaller.isOurs([
        "type": "command",
        "command": HookInstaller.command(socketPath: socket, token: token, timeout: 5),
      ]))
  }

  @Test func uninstallRemovesOnlyOurEntries() throws {
    defer { cleanUp() }
    try write(
      #"{ "hooks": { "Stop": [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:9000/claude/hook" }] }] } }"#
    )
    try installer.apply(try installer.planInstall(token: token))
    try installer.apply(try installer.planUninstall())
    let hooks = try #require(try read()["hooks"] as? [String: Any])
    #expect(hooks.keys.sorted() == ["Stop"])
    #expect(try installer.status(token: token) == .notInstalled)
  }

  @Test func invalidJSONIsNeverOverwritten() throws {
    defer { cleanUp() }
    try write("{ not json")
    #expect(throws: HookInstaller.Failure.unreadable) {
      try installer.planInstall(token: token)
    }
    #expect(
      String(decoding: try Data(contentsOf: installer.settingsURL), as: UTF8.self) == "{ not json")
  }

  @Test func unreadableFileIsNotTreatedAsEmpty() throws {
    defer { cleanUp() }
    try write(#"{ "model": "opus" }"#)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0], ofItemAtPath: installer.settingsURL.path())
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o600], ofItemAtPath: installer.settingsURL.path())
    }
    #expect(throws: HookInstaller.Failure.unreadable) { try installer.status(token: token) }
  }

  @Test func writesThroughSymlinks() throws {
    defer { cleanUp() }
    try write(#"{ "model": "opus" }"#, to: "real.json")
    try FileManager.default.createSymbolicLink(
      at: installer.settingsURL, withDestinationURL: folder.appending(path: "real.json"))
    try installer.apply(try installer.planInstall(token: token))
    let link = try FileManager.default.destinationOfSymbolicLink(
      atPath: installer.settingsURL.path())
    #expect(link.hasSuffix("real.json"))
    #expect(try read("real.json")["hooks"] != nil)
  }

  @Test func changesAfterReviewAreNotOverwritten() throws {
    defer { cleanUp() }
    try write(#"{ "model": "opus" }"#)
    let plan = try installer.planInstall(token: token)
    try write(#"{ "model": "sonnet" }"#)
    #expect(throws: HookInstaller.Failure.changedSinceReview) { try installer.apply(plan) }
  }

  @Test func flagsReformatting() throws {
    defer { cleanUp() }
    try write(#"{"model":"opus"}"#)
    let plan = try installer.planInstall(token: token)
    #expect(plan.reformats)
    try installer.apply(plan)
    #expect(!(try installer.planUninstall()).reformats)
  }

  @Test func formattingChangesAfterReviewAreNotOverwritten() throws {
    defer { cleanUp() }
    try write(#"{ "model": "opus" }"#)
    let plan = try installer.planInstall(token: token)
    try write(#"{"model": "opus"}"#)
    #expect(throws: HookInstaller.Failure.changedSinceReview) { try installer.apply(plan) }
  }

  @Test func diffMasksTheToken() throws {
    defer { cleanUp() }
    let plan = try installer.planInstall(token: token)
    #expect(plan.newText.contains(token))
    #expect(!plan.diff.contains { $0.text.contains(token) })
    #expect(plan.diff.contains { $0.text.contains("X-Cumba-Token: ••••••••") })
  }

  @Test func detectsDisabledHooks() throws {
    defer { cleanUp() }
    try write(#"{ "disableAllHooks": true }"#)
    #expect(try installer.hooksAreDisabled())
  }

  @Test func diffShowsAddedAndRemovedLines() {
    let lines = DiffLine.lines(from: "a\nb\nc", to: "a\nx\nc")
    #expect(lines.map(\.kind) == [.context, .removed, .added, .context])
  }
}
