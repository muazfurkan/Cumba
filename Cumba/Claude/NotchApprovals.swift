/// Which Claude Code permission requests can be allowed from the notch. Allow in the notch
/// is the same as Allow in Claude Code: the tool runs right away. Deny and In Terminal are
/// always offered.
enum NotchApprovals: String, CaseIterable, Sendable {
  case all
  case exceptShell
  case never

  /// Tools that run shell commands: Claude Code's, and the names Codex has used for its own.
  static let shellTools: Set<String> = ["Bash", "shell", "local_shell", "exec_command"]

  func allows(toolName: String) -> Bool {
    switch self {
    case .all: true
    case .exceptShell: !Self.shellTools.contains(toolName)
    case .never: false
    }
  }
}
