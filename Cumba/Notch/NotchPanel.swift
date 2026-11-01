import AppKit

/// Borderless, non-activating panel above the menu bar. It becomes key only when a text
/// view in it is clicked (the Notes widget), so hovering or clicking buttons never takes
/// keyboard focus from the app you're working in.
final class NotchPanel: NSPanel {
  /// Above the menu bar and its status items, below the menus they open. Full screen apps
  /// put their title bar in a window one level above the status items (26); sharing that
  /// level, the notch went behind it whenever the menu bar slid down, so it sits one higher.
  static let notchLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)

  init(showsInFullScreen: Bool) {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false)
    level = Self.notchLevel
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    isMovable = false
    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    animationBehavior = .none
    acceptsMouseMovedEvents = true
    becomesKeyOnlyIfNeeded = true
    // Clicks pass through to the menu bar until the pointer is over the shape.
    ignoresMouseEvents = true
    // Without .fullScreenAuxiliary the panel stays off full screen spaces.
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    if showsInFullScreen {
      collectionBehavior.insert(.fullScreenAuxiliary)
    }
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  // Keep the frame exactly where it is placed, even over the menu bar.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }
}
