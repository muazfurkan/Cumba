import Foundation

/// A Claude Code hook event as posted to `/claude/hook` (SPEC § 9). Only the fields the
/// app uses are decoded; everything is optional so new or missing fields never fail.
/// Payloads stay in memory and are never logged or written to disk.
struct HookPayload: Decodable, Sendable {
  enum Event: String, Sendable {
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case notification = "Notification"
    case stop = "Stop"
    case stopFailure = "StopFailure"
    case sessionEnd = "SessionEnd"
  }

  var sessionID: String
  var hookEventName: String
  var cwd: String?
  var toolName: String?
  var toolInput: [String: JSONValue]?
  var message: String?
  var notificationType: String?
  var lastAssistantMessage: String?
  var error: String?
  var reason: String?

  var event: Event? { Event(rawValue: hookEventName) }

  /// Folder name of the working directory, e.g. "ljaspNotch".
  var project: String {
    guard let cwd, !cwd.isEmpty else { return String(localized: "Claude Code") }
    return URL(filePath: cwd).lastPathComponent
  }

  private enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
    case hookEventName = "hook_event_name"
    case cwd
    case toolName = "tool_name"
    case toolInput = "tool_input"
    case message
    case notificationType = "notification_type"
    case lastAssistantMessage = "last_assistant_message"
    case error
    case reason
  }

  /// Biggest body accepted; real payloads are a few kilobytes.
  static let maxBodySize = 1_000_000

  static func decode(_ data: Data) -> HookPayload? {
    guard data.count <= maxBodySize else { return nil }
    return try? JSONDecoder().decode(HookPayload.self, from: data)
  }

  /// Short description of a permission request: the command for Bash, the file for edits,
  /// the URL for fetches, otherwise the tool name.
  var permissionSummary: String {
    let tool = toolName ?? "?"
    let detail: String? =
      switch tool {
      case "Bash": toolInput?["command"]?.string
      case "Edit", "Write", "MultiEdit", "NotebookEdit", "Read":
        (toolInput?["file_path"]?.string ?? toolInput?["notebook_path"]?.string)
          .map { Self.shortPath($0, relativeTo: cwd) }
      case "WebFetch": toolInput?["url"]?.string
      case "WebSearch": toolInput?["query"]?.string
      default: nil
      }
    return Self.truncate(detail ?? tool, to: 160)
  }

  static func truncate(_ text: String, to length: Int) -> String {
    let singleLine = text.replacingOccurrences(of: "\n", with: " ")
    guard singleLine.count > length else { return singleLine }
    return String(singleLine.prefix(length - 1)) + "…"
  }

  /// Path relative to the project when inside it, otherwise the last two components.
  static func shortPath(_ path: String, relativeTo cwd: String?) -> String {
    if let cwd, path.hasPrefix(cwd + "/") {
      return String(path.dropFirst(cwd.count + 1))
    }
    return URL(filePath: path).pathComponents.suffix(2).joined(separator: "/")
  }
}

/// Minimal JSON value for tool inputs, which differ per tool.
enum JSONValue: Decodable, Equatable, Sendable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case array([JSONValue])
  case object([String: JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  var string: String? {
    if case .string(let value) = self { value } else { nil }
  }
}
