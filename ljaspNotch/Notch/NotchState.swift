/// Visual state of the notch panel (SPEC § 6).
enum NotchState: CaseIterable, Sendable {
  /// Notch-sized and practically invisible.
  case closed
  /// Small indicators on both sides of the notch for a live activity.
  case peek
  /// Full panel, opened by hover or click.
  case expanded
  /// Like `expanded`, but stays open until unpinned.
  case pinned

  var isOpen: Bool {
    self == .expanded || self == .pinned
  }
}
