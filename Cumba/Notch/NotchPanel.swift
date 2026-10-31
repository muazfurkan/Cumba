import AppKit

/// Borderless, non-activating panel above the menu bar. It becomes key only when a text
/// view in it is clicked (the Notes widget), so hovering or clicking buttons never takes
/// keyboard focus from the app you're working in.
final class NotchPanel: NSPanel {
  /// Above the menu bar and its status items, below the menus they open.
  static let notchLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

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
