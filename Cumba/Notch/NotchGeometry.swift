import CoreGraphics

/// Panel sizes. Themes provide these from Phase 2 on.
struct NotchLayout: Equatable, Sendable {
  var expandedSize = CGSize(width: 640, height: 190)
  /// Width added on each side of the notch in the peek state.
  var peekExtraWidth: CGFloat = 70
  /// Room for the expanded panel's shadow, part of the fixed window size.
  var shadowMargin: CGFloat = 24
  /// Extra horizontal room around the closed notch that still counts as hovering it.
  var hoverMargin: CGFloat = 8
}

extension NotchLayout {
  init(theme: Theme) {
    self.init()
    expandedSize = CGSize(width: theme.expandedSize.width, height: theme.expandedSize.height)
    peekExtraWidth = theme.peekExtraWidth
  }
}

/// Notch position and panel frames for one screen. A pure value so it can be unit tested.
/// All rects are in AppKit screen coordinates (origin at the bottom left).
struct NotchGeometry: Equatable, Sendable {
  let screenFrame: CGRect
  let notchRect: CGRect
  let layout: NotchLayout
  /// Drawn by the app on a screen without a camera housing.
  let isVirtual: Bool

  /// Returns nil when the screen has no notch.
  init?(
    screenFrame: CGRect,
    safeAreaTop: CGFloat,
    leftAreaWidth: CGFloat,
    rightAreaWidth: CGFloat,
    layout: NotchLayout = NotchLayout()
  ) {
    let notchWidth = screenFrame.width - leftAreaWidth - rightAreaWidth
    guard safeAreaTop > 0, notchWidth > 0 else { return nil }
    self.screenFrame = screenFrame
    self.notchRect = CGRect(
      x: screenFrame.minX + leftAreaWidth,
      y: screenFrame.maxY - safeAreaTop,
      width: notchWidth,
      height: safeAreaTop)
    self.layout = layout
    isVirtual = false
  }

  /// A notch drawn in the middle of the menu bar, for screens without one.
  init(
    virtualOn screenFrame: CGRect, menuBarHeight: CGFloat, width: CGFloat = 200,
    layout: NotchLayout = NotchLayout()
  ) {
    self.screenFrame = screenFrame
    notchRect = CGRect(
      x: screenFrame.midX - width / 2, y: screenFrame.maxY - menuBarHeight, width: width,
      height: menuBarHeight)
    self.layout = layout
    isVirtual = true
  }

  /// The window never changes size: it fits the largest shape plus its shadow and is
  /// centered under the notch. State changes only animate the shape inside it.
  var windowFrame: CGRect {
    let largest = CGSize(
      width: max(shapeSize(for: .expanded).width, shapeSize(for: .peek).width),
      height: shapeSize(for: .expanded).height)
    let width = largest.width + layout.shadowMargin * 2
    let height = largest.height + layout.shadowMargin
    return CGRect(
      x: notchRect.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
  }

  func shapeSize(for state: NotchState) -> CGSize {
    switch state {
    case .closed:
      notchRect.size
    case .peek:
      CGSize(width: notchRect.width + layout.peekExtraWidth * 2, height: notchRect.height)
    case .expanded, .pinned:
      CGSize(
        width: max(layout.expandedSize.width, notchRect.width),
        height: max(layout.expandedSize.height, notchRect.height))
    }
  }

  /// Screen rect of the visible shape, hanging from the top edge under the notch.
  func shapeRect(for state: NotchState) -> CGRect {
    let size = shapeSize(for: state)
    return CGRect(
      x: notchRect.midX - size.width / 2,
      y: screenFrame.maxY - size.height,
      width: size.width,
      height: size.height)
  }

  /// Area where the pointer counts as being over the panel. It reaches one point past
  /// the top edge so a pointer pushed against the top of the screen still counts.
  func hoverRect(for state: NotchState) -> CGRect {
    var rect = shapeRect(for: state)
    if !state.isOpen {
      rect = rect.insetBy(dx: -layout.hoverMargin, dy: 0)
    }
    rect.size.height += 1
    return rect
  }
}
