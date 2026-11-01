import AppKit

/// Picks the screen for the panel and sizes the panel on it, from the settings and what
/// the open tab shows.
@MainActor
enum NotchScreenLayout {
  /// The screen chosen in Settings. "Notched" falls back to the main screen with the virtual
  /// notch setting; the other choices draw a virtual notch where there is no real one.
  static func target(
    settings: AppSettings, host: WidgetHost, layoutStore: LayoutStore,
    screenUnderPointer: NSScreen?
  ) -> (screen: NSScreen, geometry: NotchGeometry)? {
    let chosen: NSScreen?
    switch settings.panelScreen {
    case .notched: chosen = NSScreen.notched
    case .main: chosen = NSScreen.screens.first
    case .pointer: chosen = screenUnderPointer
    }
    let fallback = settings.usesVirtualNotch ? NSScreen.screens.first : nil
    guard let screen = chosen ?? fallback else { return nil }
    var layout = baseLayout(settings: settings, host: host)
    func geometry() -> NotchGeometry {
      screen.notchGeometry(layout: layout) ?? screen.virtualNotchGeometry(layout: layout)
    }
    size(
      &layout, on: screen, notchHeight: geometry().notchRect.height, settings: settings,
      host: host, layoutStore: layoutStore)
    return (screen, geometry())
  }

  /// The layout before the open tab sizes the panel: the settings, the tab bar and what the
  /// live activity beside the notch needs.
  private static func baseLayout(settings: AppSettings, host: WidgetHost) -> NotchLayout {
    var layout = NotchLayout(size: settings.panelSize)
    // Tabs at the bottom get their own strip below the widgets.
    switch settings.tabBarStyle {
    case .inPanel: layout.expandedSize.height += NotchLayout.bottomTabBarHeight
    case .compact, .icons, .dots: layout.tabBarRoom = NotchLayout.floatingTabBarRoom
    case .top: break
    }
    // A live activity can ask for wider sides.
    if let sideWidth = host.liveActivities.current?.sideWidth {
      layout.peekExtraWidth = max(layout.peekExtraWidth, sideWidth)
    }
    if host.liveActivities.current?.notification != nil {
      layout.peekNotificationHeight = NotchLayout.notificationHeight
    }
    return layout
  }

  /// Sizes the open panel for the open tab: wider for more widgets, up to the screen less a
  /// margin, and taller when a widget needs it, up to 60% of the screen. Also sets how many
  /// size units a tab may hold on this screen.
  private static func size(
    _ layout: inout NotchLayout, on screen: NSScreen, notchHeight: CGFloat,
    settings: AppSettings, host: WidgetHost, layoutStore: LayoutStore
  ) {
    let base = layout.expandedSize
    let maxWidth = screen.frame.width - WidgetLayout.screenMargin * 2
    let maxHeight = screen.frame.height * 0.6
    let capacity = WidgetLayout.capacity(panelWidth: base.width, screenWidth: screen.frame.width)
    if layoutStore.unitsPerTab != capacity {
      layoutStore.unitsPerTab = capacity
    }
    // The band beside the camera, the gap above the widgets and the bottom padding or bar.
    let chrome = notchHeight + 8 + (settings.tabBarStyle == .inPanel ? 40 : 14)
    func panel(for tab: WidgetLayout.Tab?) -> CGSize {
      let width = host.preferredPanelWidth(for: tab, baseWidth: base.width, maxWidth: maxWidth)
      let height = host.preferredPanelHeight(
        for: tab, width: width, baseHeight: base.height, maxHeight: maxHeight, chrome: chrome,
        textScale: settings.panelSize.textScale)
      return CGSize(width: width, height: height)
    }
    let open = panel(for: host.selectedTab)
    layout.panelWidth = open.width
    layout.panelHeight = open.height
    let all = host.tabs.map(panel(for:)) + [open]
    layout.largestPanel = CGSize(
      width: all.map(\.width).max() ?? open.width, height: all.map(\.height).max() ?? open.height)
  }
}
