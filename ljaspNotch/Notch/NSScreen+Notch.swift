import AppKit

extension NSScreen {
  /// The screen with a camera housing, if any. Only built-in displays of notched Macs have one.
  static var notched: NSScreen? {
    screens.first { $0.safeAreaInsets.top > 0 }
  }

  func notchGeometry(layout: NotchLayout = NotchLayout()) -> NotchGeometry? {
    guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
    return NotchGeometry(
      screenFrame: frame,
      safeAreaTop: safeAreaInsets.top,
      leftAreaWidth: left.width,
      rightAreaWidth: right.width,
      layout: layout)
  }
}
