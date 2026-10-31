import AppKit

extension NSScreen {
  /// The screen with a camera housing, if any. Only built-in displays of notched Macs have one.
  static var notched: NSScreen? {
    screens.first { $0.safeAreaInsets.top > 0 }
  }

  /// Frame in Core Graphics coordinates (origin at the top left of the primary screen),
  /// as used by the window list.
  var cgFrame: CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.maxY ?? frame.maxY
    return CGRect(
      x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
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

  /// A drawn notch centered in this screen's menu bar.
  func virtualNotchGeometry(layout: NotchLayout = NotchLayout()) -> NotchGeometry {
    let menuBarHeight = frame.maxY - visibleFrame.maxY
    return NotchGeometry(
      virtualOn: frame, menuBarHeight: menuBarHeight > 0 ? menuBarHeight : 24, layout: layout)
  }
}
