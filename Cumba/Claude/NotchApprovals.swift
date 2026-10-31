/// Which Claude Code permission requests can be allowed from the notch. Allow in the notch
/// is the same as Allow in Claude Code: the tool runs right away. Deny and In Terminal are
/// always offered.
enum NotchApprovals: String, CaseIterable, Sendable {
  case all
  case exceptShell
  case never

  /// Claude Code tools that run shell commands.
  static let shellTools: Set<String> = ["Bash"]

  func allows(toolName: String) -> Bool {
    switch self {
    case .all: true
    case .exceptShell: !Self.shellTools.contains(toolName)
    case .never: false
    }
  }
}
