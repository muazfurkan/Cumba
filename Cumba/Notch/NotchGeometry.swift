import CoreGraphics

/// Panel sizes, from `PanelSize` in the settings.
struct NotchLayout: Equatable, Sendable {
  var expandedSize = CGSize(width: 640, height: 190)
  /// Width added on each side of the notch in the peek state.
  var peekExtraWidth: CGFloat = 70
  /// Width of the expanded panel for what it shows now, at most `expandedSize.width`;
  /// `nil` uses the full width. The window stays sized for the full width.
  var panelWidth: CGFloat?
  /// Room for the expanded panel's shadow, part of the fixed window size.
  var shadowMargin: CGFloat = 24
  /// Room under the open panel for a tab bar of its own; 0 when the tabs are inside it.
  var tabBarRoom: CGFloat = 0
  /// Extra horizontal room around the closed notch that still counts as hovering it.
  var hoverMargin: CGFloat = 8

  /// Room under the closed notch for a live activity's notification; 0 without one.
  var peekNotificationHeight: CGFloat = 0
  /// How far the closed shape reaches past the camera housing on each side and below it,
  /// so the notch reads as part of the app instead of disappearing into the hardware.
  var closedGrowth = CGSize(width: 8, height: 5)

  /// Added to the panel's height when the tabs sit at its bottom.
  static let bottomTabBarHeight: CGFloat = 36
  /// Room under the open panel for a tab bar of its own: the gap, the bar and its shadow.
  static let floatingTabBarRoom: CGFloat = 52
  static let notificationHeight: CGFloat = 62
  /// The peek is at least this wide while a notification is open.
  static let notificationWidth: CGFloat = 440
}

extension NotchLayout {
  init(size: PanelSize) {
    self.init()
    expandedSize = CGSize(width: size.width, height: size.height)
    peekExtraWidth = size.indicatorWidth
    closedGrowth = CGSize(width: size.closedWidth, height: size.closedHeight)
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
      width: max(layout.expandedSize.width, notchRect.width, shapeSize(for: .peek).width),
      height: shapeSize(for: .expanded).height)
    let width = largest.width + layout.shadowMargin * 2
    let height = largest.height + max(layout.shadowMargin, layout.tabBarRoom)
    return CGRect(
      x: notchRect.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
  }

  /// Width of each side of the peek; never narrower than the closed notch.
  var peekSideWidth: CGFloat { max(layout.peekExtraWidth, layout.closedGrowth.width) }

  /// Height of the peek's row of icons, without a notification: as tall as the closed
  /// notch, so at zero both are exactly the camera housing's height.
  var peekRowHeight: CGFloat {
    notchRect.height + layout.closedGrowth.height
  }

  func shapeSize(for state: NotchState) -> CGSize {
    switch state {
    case .closed:
      CGSize(
        width: notchRect.width + layout.closedGrowth.width * 2,
        height: notchRect.height + layout.closedGrowth.height)
    case .peek:
      CGSize(
        width: max(
          notchRect.width + peekSideWidth * 2,
          layout.peekNotificationHeight > 0 ? NotchLayout.notificationWidth : 0),
        height: peekRowHeight + layout.peekNotificationHeight)
    case .expanded, .pinned:
      CGSize(
        width: max(min(layout.panelWidth ?? .infinity, layout.expandedSize.width), notchRect.width),
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
    } else if layout.tabBarRoom > 0 {
      // The tab bar under the panel counts as part of it.
      rect.origin.y -= layout.tabBarRoom
      rect.size.height += layout.tabBarRoom
    }
    rect.size.height += 1
    return rect
  }
}
