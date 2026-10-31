import Foundation

/// Adds ljaspNotch's HTTP hooks to `~/.claude/settings.json` and removes them again
/// (SPEC § 9). Other settings and hooks are kept. The user always sees a diff first; the
/// file is backed up and written atomically. Every method does file I/O, so call them off
/// the main thread.
struct HookInstaller: Sendable {
  enum Status: Equatable, Sendable {
    case notInstalled
    case installed
    /// Some entries exist but with another port, token or timeout.
    case outdated
  }

  enum Failure: Error, Equatable {
    /// The file exists but isn't a JSON object; it is never overwritten.
    case unreadable
    /// The file changed after the diff was shown.
    case changedSinceReview
    case writeFailed(String)
  }

  /// What a change would do, shown to the user before anything is written.
  struct Plan: Equatable, Sendable {
    let oldText: String
    let newText: String
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

  static var standard: HookInstaller {
    HookInstaller(
      settingsURL: FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/settings.json"))
  }

  static func hookURL(port: UInt16) -> String {
    "http://127.0.0.1:\(port)/claude/hook"
  }

  // MARK: - File access

  func status(port: UInt16, token: String) throws(Failure) -> Status {
    Self.status(of: try readSettings(), port: port, token: token)
  }

  /// True when `allowedHttpHookUrls` exists and none of its patterns allow our URL.
  func isBlockedByAllowlist(port: UInt16) throws(Failure) -> Bool {
    Self.isBlocked(url: Self.hookURL(port: port), in: try readSettings())
  }

  func planInstall(port: UInt16, token: String) throws(Failure) -> Plan {
    let settings = try readSettings()
    return Self.plan(from: settings, to: Self.installing(port: port, token: token, into: settings))
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
    let manager = FileManager.default
    do {
      var backup: URL?
      if manager.fileExists(atPath: settingsURL.path(percentEncoded: false)) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = settingsURL.deletingLastPathComponent()
        let stamp = "settings.json.bak-\(formatter.string(from: now))"
        // Two saves within a second get "-2", "-3" … instead of failing.
        var url = folder.appending(path: stamp)
        var counter = 2
        while manager.fileExists(atPath: url.path(percentEncoded: false)) {
          url = folder.appending(path: "\(stamp)-\(counter)")
          counter += 1
        }
        try manager.copyItem(at: settingsURL, to: url)
        backup = url
      } else {
        try manager.createDirectory(
          at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      }
      try Data((plan.newText + "\n").utf8).write(to: settingsURL, options: .atomic)
      return backup
    } catch {
      throw .writeFailed(error.localizedDescription)
    }
  }

  private func readSettings() throws(Failure) -> [String: Any] {
    guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
    if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
      return [:]
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw .unreadable
    }
    return object
  }

  // MARK: - Pure transformations

  /// An entry is ours when it is an HTTP hook to `/claude/hook` on the loopback address.
  static func isOurs(_ hook: Any) -> Bool {
    guard let hook = hook as? [String: Any], hook["type"] as? String == "http",
      let url = hook["url"] as? String
    else { return false }
    return url.range(
      of: #"^http://(127\.0\.0\.1|localhost):\d+/claude/hook$"#, options: .regularExpression)
      != nil
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

  static func installing(port: UInt16, token: String, into settings: [String: Any]) -> [String: Any]
  {
    var result = removingOurs(from: settings)
    var hooks = result["hooks"] as? [String: Any] ?? [:]
    for (event, timeout) in events {
      var groups = hooks[event] as? [Any] ?? []
      groups.append([
        "hooks": [
          [
            "type": "http",
            "url": hookURL(port: port),
            "timeout": timeout,
            // A literal value: desktop apps don't inherit shell variables, so `$VAR`
            // would silently fail in the Claude desktop app.
            "headers": [RequestGuard.tokenHeader: token],
          ]
        ]
      ])
      hooks[event] = groups
    }
    result["hooks"] = hooks
    return result
  }

  static func status(of settings: [String: Any], port: UInt16, token: String) -> Status {
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
      let matches = entries.contains { entry in
        entry["url"] as? String == hookURL(port: port) && entry["timeout"] as? Int == timeout
          && (entry["headers"] as? [String: Any])?[RequestGuard.tokenHeader] as? String == token
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

  static func isBlocked(url: String, in settings: [String: Any]) -> Bool {
    guard let patterns = settings["allowedHttpHookUrls"] as? [String] else { return false }
    return !patterns.contains { pattern in
      let regex =
        "^"
        + pattern.split(separator: "*", omittingEmptySubsequences: false)
        .map { NSRegularExpression.escapedPattern(for: String($0)) }
        .joined(separator: ".*") + "$"
      return url.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }
  }

  static func render(_ settings: [String: Any]) -> String {
    guard !settings.isEmpty,
      let data = try? JSONSerialization.data(
        withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    else { return "" }
    return String(decoding: data, as: UTF8.self)
  }

  static func plan(from old: [String: Any], to new: [String: Any]) -> Plan {
    let oldText = render(old)
    let newText = render(new)
    return Plan(
      oldText: oldText, newText: newText, diff: DiffLine.lines(from: oldText, to: newText))
  }
}
