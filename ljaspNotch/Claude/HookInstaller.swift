import Foundation

/// Adds ljaspNotch's hooks to `~/.claude/settings.json` and removes them again (SPEC § 9).
///
/// The hooks are `command` hooks that pipe the event to the app's Unix socket with curl.
/// The socket lives in a folder only this user can open, so no other user or sandboxed app
/// can pose as ljaspNotch, even while the app isn't running (a TCP port could be taken over
/// then). When the app is closed, curl fails quietly and Claude Code carries on.
///
/// Other settings and hooks are kept. The user always sees a diff first (with the token
/// masked); the file is backed up and written atomically, through symlinks. Every method
/// does file I/O, so call them off the main thread.
struct HookInstaller: Sendable {
  enum Status: Equatable, Sendable {
    case notInstalled
    case installed
    /// Some entries exist but with another token, timeout or format.
    case outdated
  }

  enum Failure: Error, Equatable {
    /// The file exists but can't be read or isn't a JSON object; it is never overwritten.
    case unreadable
    /// The file changed after the diff was shown.
    case changedSinceReview
    case writeFailed(String)
  }

  /// What a change would do, shown to the user before anything is written.
  struct Plan: Equatable, Sendable {
    let oldText: String
    let newText: String
    /// Line diff with tokens masked, for display.
    let diff: [DiffLine]
    var hasChanges: Bool { oldText != newText }
  }

  /// Events, with timeouts in seconds (SPEC § 9). SessionEnd needs an explicit timeout;
  /// without one Claude Code gives all SessionEnd hooks 1.5 s together.
  static let events: [(name: String, timeout: Int)] = [
    ("UserPromptSubmit", 5), ("PermissionRequest", 300), ("Notification", 5), ("Stop", 5),
    ("StopFailure", 5), ("SessionEnd", 2),
  ]

  let settingsURL: URL
  let socketPath: String

  static var standard: HookInstaller {
    HookInstaller(
      settingsURL: FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/settings.json"),
      socketPath: LocalServer.hookSocketURL.path(percentEncoded: false))
  }

  /// Settings path with symlinks resolved, so dotfile setups keep their link.
  private var resolvedURL: URL { settingsURL.resolvingSymlinksInPath() }

  // MARK: - File access

  func status(token: String) throws(Failure) -> Status {
    Self.status(of: try readSettings(), socketPath: socketPath, token: token)
  }

  /// True when `disableAllHooks` is set, so Claude Code ignores every hook.
  func hooksAreDisabled() throws(Failure) -> Bool {
    try readSettings()["disableAllHooks"] as? Bool == true
  }

  func planInstall(token: String) throws(Failure) -> Plan {
    let settings = try readSettings()
    return Self.plan(
      from: settings, to: Self.installing(socketPath: socketPath, token: token, into: settings))
  }

  func planUninstall() throws(Failure) -> Plan {
    let settings = try readSettings()
    return Self.plan(from: settings, to: Self.removingOurs(from: settings))
  }

  /// Writes the reviewed plan. Backs up the old file first; returns the backup's URL.
  @discardableResult
  func apply(_ plan: Plan, now: Date = .now) throws(Failure) -> URL? {
    let current = try readSettings()
    guard Self.render(current) == plan.oldText else { throw .changedSinceReview }
    let target = resolvedURL
    let manager = FileManager.default
    do {
      var backup: URL?
      if manager.fileExists(atPath: target.path(percentEncoded: false)) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = target.deletingLastPathComponent()
        let stamp = "settings.json.bak-\(formatter.string(from: now))"
        // Two saves within a second get "-2", "-3" … instead of failing.
        var url = folder.appending(path: stamp)
        var counter = 2
        while manager.fileExists(atPath: url.path(percentEncoded: false)) {
          url = folder.appending(path: "\(stamp)-\(counter)")
          counter += 1
        }
        try manager.copyItem(at: target, to: url)
        // The backup holds the token too; keep it private like the original.
        try manager.setAttributes(
          [.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
        backup = url
      } else {
        try manager.createDirectory(
          at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      }
      try Data((plan.newText + "\n").utf8).write(to: target, options: .atomic)
      return backup
    } catch {
      throw .writeFailed(error.localizedDescription)
    }
  }

  /// A missing file counts as empty; any other read error is a failure, so a file we
  /// can't read (e.g. owned by root) is never replaced.
  private func readSettings() throws(Failure) -> [String: Any] {
    let url = resolvedURL
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
      return [:]
    }
    guard let data = try? Data(contentsOf: url) else { throw .unreadable }
    if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
      return [:]
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw .unreadable
    }
    return object
  }

  // MARK: - Pure transformations

  /// The shell command of one hook. curl fails quietly (`-sf`, `|| true`) when the app isn't
  /// running, and gives up a second before Claude Code's own timeout.
  static func command(socketPath: String, token: String, timeout: Int) -> String {
    let header = "\(RequestGuard.tokenHeader): \(token)"
    return [
      "/usr/bin/curl -sf --max-time \(max(1, timeout - 1))",
      "--unix-socket \(shellQuoted(socketPath))",
      "-H \(shellQuoted(header)) -H 'Content-Type: application/json'",
      "--data-binary @- http://localhost/claude/hook || true",
    ].joined(separator: " ")
  }

  static func shellQuoted(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
  }

  /// Ours: a command hook that posts to our socket, or an HTTP hook from earlier versions
  /// that carries our token header. Hooks of other tools on the same path are left alone.
  static func isOurs(_ hook: Any) -> Bool {
    guard let hook = hook as? [String: Any] else { return false }
    switch hook["type"] as? String {
    case "command":
      guard let command = hook["command"] as? String else { return false }
      return command.contains("--unix-socket") && command.contains("ljaspNotch/hook.sock")
        && command.contains("/claude/hook")
    case "http":
      guard let url = hook["url"] as? String,
        url.range(
          of: #"^http://(127\.0\.0\.1|localhost):\d+/claude/hook$"#, options: .regularExpression)
          != nil
      else { return false }
      return (hook["headers"] as? [String: Any])?[RequestGuard.tokenHeader] != nil
    default:
      return false
    }
  }

  static func removingOurs(from settings: [String: Any]) -> [String: Any] {
    guard var hooks = settings["hooks"] as? [String: Any] else { return settings }
    for (event, value) in hooks {
      guard let groups = value as? [Any] else { continue }
      let cleaned = groups.compactMap { group -> Any? in
        guard var group = group as? [String: Any], let entries = group["hooks"] as? [Any] else {
          return group
        }
        let kept = entries.filter { !isOurs($0) }
        if kept.isEmpty && !entries.isEmpty {
          return nil
        }
        group["hooks"] = kept
        return group
      }
      hooks[event] = cleaned.isEmpty ? nil : cleaned
    }
    var result = settings
    result["hooks"] = hooks.isEmpty ? nil : hooks
    return result
  }

  static func installing(socketPath: String, token: String, into settings: [String: Any])
    -> [String: Any]
  {
    var result = removingOurs(from: settings)
    var hooks = result["hooks"] as? [String: Any] ?? [:]
    for (event, timeout) in events {
      var groups = hooks[event] as? [Any] ?? []
      groups.append([
        "hooks": [
          [
            "type": "command",
            "command": command(socketPath: socketPath, token: token, timeout: timeout),
            "timeout": timeout,
          ]
        ]
      ])
      hooks[event] = groups
    }
    result["hooks"] = hooks
    return result
  }

  static func status(of settings: [String: Any], socketPath: String, token: String) -> Status {
    let hooks = settings["hooks"] as? [String: Any] ?? [:]
    var found = 0
    var current = 0
    for (event, timeout) in events {
      let entries = (hooks[event] as? [Any] ?? [])
        .compactMap { ($0 as? [String: Any])?["hooks"] as? [Any] }
        .flatMap { $0 }
        .filter(isOurs)
        .compactMap { $0 as? [String: Any] }
      guard !entries.isEmpty else { continue }
      found += 1
      let expected = command(socketPath: socketPath, token: token, timeout: timeout)
      let matches = entries.contains { entry in
        entry["command"] as? String == expected && entry["timeout"] as? Int == timeout
      }
      if matches && entries.count == 1 {
        current += 1
      }
    }
    if found == 0 {
      return .notInstalled
    }
    return current == events.count ? .installed : .outdated
  }

  static func render(_ settings: [String: Any]) -> String {
    guard !settings.isEmpty,
      let data = try? JSONSerialization.data(
        withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    else { return "" }
    return String(decoding: data, as: UTF8.self)
  }

  /// Hides token values so the diff can be shown or screenshotted safely.
  static func maskingTokens(in text: String) -> String {
    text.replacingOccurrences(
      of: "\(RequestGuard.tokenHeader)([\"']?\\s*:\\s*[\"']?)[0-9a-fA-F]{16,}",
      with: "\(RequestGuard.tokenHeader)$1••••••••", options: .regularExpression)
  }

  static func plan(from old: [String: Any], to new: [String: Any]) -> Plan {
    let oldText = render(old)
    let newText = render(new)
    return Plan(
      oldText: oldText, newText: newText,
      diff: DiffLine.lines(from: maskingTokens(in: oldText), to: maskingTokens(in: newText)))
  }
}
