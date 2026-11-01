import Foundation

/// A Claude Code hook event as posted to `/claude/hook`. Only the fields the
/// app uses are decoded; everything is optional so new or missing fields never fail.
/// Payloads stay in memory and are never logged or written to disk.
struct HookPayload: Decodable, Sendable {
  enum Event: String, Sendable {
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
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
  /// The prompt, on UserPromptSubmit.
  var prompt: String?
  /// The session transcript (JSON lines under ~/.claude/projects).
  var transcriptPath: String?
  var error: String?
  var reason: String?

  var event: Event? { Event(rawValue: hookEventName) }

  /// Folder name of the working directory, e.g. "my-project".
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
    case prompt
    case transcriptPath = "transcript_path"
    case error
    case reason
  }

  /// Biggest body accepted; real payloads are a few kilobytes.
  static let maxBodySize = 1_000_000

  static func decode(_ data: Data) -> HookPayload? {
    guard data.count <= maxBodySize else { return nil }
    return try? JSONDecoder().decode(HookPayload.self, from: data)
  }

  /// What the permission request would do, in full and safe to show: the command for
  /// Bash, the file for edits, the URL for fetches, otherwise the whole tool input as JSON.
  var permissionDetail: SafeText {
    let tool = toolName ?? "?"
    let known: String? =
      switch tool {
      case "Bash": toolInput?["command"]?.string
      case "Edit", "Write", "MultiEdit", "NotebookEdit", "Read":
        (toolInput?["file_path"]?.string ?? toolInput?["notebook_path"]?.string)
          .map { Self.shortPath($0, relativeTo: cwd) }
      case "WebFetch": toolInput?["url"]?.string
      case "WebSearch": toolInput?["query"]?.string
      default: nil
      }
    return SafeText(known ?? JSONValue.object(toolInput ?? [:]).rendered())
  }

  static func truncate(_ text: String, to length: Int) -> String {
    let singleLine = text.replacingOccurrences(of: "\n", with: " ")
    guard singleLine.count > length else { return singleLine }
    return String(singleLine.prefix(length - 1)) + "…"
  }

  /// Path relative to the project when inside it, otherwise the full path. `..` is
  /// resolved first, so a path can't look like it stays inside the project when it doesn't.
  static func shortPath(_ path: String, relativeTo cwd: String?) -> String {
    let standardized = URL(filePath: path).standardized.path(percentEncoded: false)
    if let cwd {
      let root = URL(filePath: cwd).standardized.path(percentEncoded: false)
      if standardized.hasPrefix(root + "/") {
        return String(standardized.dropFirst(root.count + 1))
      }
    }
    return standardized
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

  /// Indented JSON with sorted keys, for showing unknown tool inputs.
  func rendered(indent: String = "") -> String {
    let inner = indent + "  "
    switch self {
    case .string(let value):
      let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      return "\"\(escaped)\""
    case .number(let value):
      return value.rounded() == value && abs(value) < 1e15
        ? String(Int(value)) : String(value)
    case .bool(let value):
      return value ? "true" : "false"
    case .null:
      return "null"
    case .array(let values):
      guard !values.isEmpty else { return "[]" }
      return "[\n" + values.map { inner + $0.rendered(indent: inner) }.joined(separator: ",\n")
        + "\n\(indent)]"
    case .object(let fields):
      guard !fields.isEmpty else { return "{}" }
      return "{\n"
        + fields.keys.sorted().map { key in
          "\(inner)\"\(key)\": \(fields[key]?.rendered(indent: inner) ?? "null")"
        }.joined(separator: ",\n") + "\n\(indent)}"
    }
  }
}
