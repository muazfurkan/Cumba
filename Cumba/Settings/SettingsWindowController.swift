import AppKit
import SwiftUI

/// Owns the Settings window: an AppKit toolbar-style tab view whose tabs are SwiftUI views.
/// The SwiftUI `Settings` scene is not used because opening it from a menu bar item
/// needs an undocumented selector.
@MainActor
final class SettingsWindowController {
  enum Tab: Int {
    case general
    case appearance
    case widgets
    case connections
    case claudeCode
    case permissions
  }

  private let settings: AppSettings
  private let themes: ThemeStore
  private let layoutStore: LayoutStore
  private let registry: WidgetRegistry
  private let server: LocalServer
  private let updates: UpdateChecker
  private var window: NSWindow?
  private var tabController: SettingsTabViewController?
  private var closeObserver: NSObjectProtocol?

  init(
    settings: AppSettings, themes: ThemeStore, layoutStore: LayoutStore,
    registry: WidgetRegistry, server: LocalServer, updates: UpdateChecker
  ) {
    self.settings = settings
    self.themes = themes
    self.layoutStore = layoutStore
    self.registry = registry
    self.server = server
    self.updates = updates
  }

  func show(tab: Tab? = nil) {
    let window = window ?? makeWindow()
    self.window = window
    if let tab {
      tabController?.selectedTabViewItemIndex = tab.rawValue
    }
    Task { await settings.refreshLaunchAtLogin() }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let tabs = SettingsTabViewController()
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(
      tab(
        GeneralSettingsView(
          settings: settings, updates: updates,
          diagnostics: Diagnostics.Sources(
            settings: settings, themes: themes, layout: layoutStore, server: server)),
        label: String(localized: "General", comment: "Settings tab"),
        symbol: "gearshape"))
    tabs.addTabViewItem(
      tab(
        AppearanceSettingsView(themes: themes, settings: settings),
        label: String(localized: "Appearance", comment: "Settings tab"),
        symbol: "paintpalette"))
    tabs.addTabViewItem(
      tab(
        WidgetsSettingsView(layoutStore: layoutStore, registry: registry),
        label: String(localized: "Widgets", comment: "Settings tab"),
        symbol: "square.grid.2x2"))
    tabs.addTabViewItem(
      tab(
        ConnectionsSettingsView(server: server, settings: settings),
        label: String(localized: "Connections", comment: "Settings tab"),
        symbol: "network"))
    tabs.addTabViewItem(
      tab(
        ClaudeCodeSettingsView(
          server: server, settings: settings,
          onHooksInstalled: { [layoutStore] in layoutStore.addAnywhere(ClaudeCodeWidget.kind) }),
        label: "Claude Code",
        symbol: "terminal"))
    tabs.addTabViewItem(
      tab(
        PermissionsSettingsView(),
        label: String(localized: "Permissions", comment: "Settings tab"),
        symbol: "hand.raised"))
    tabs.restoreSelection()
    tabController = tabs

    let window = NSWindow(contentViewController: tabs)
    // Settings windows have no minimize button (HIG).
    window.styleMask = [.titled, .closable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    // While this app is active, pointer moves reach the notch hover tracker only
    // through this window.
    window.acceptsMouseMovedEvents = true
    window.center()
    window.setFrameAutosaveName("SettingsWindow")
    // SwiftUI doesn't always report onDisappear when the window closes; end the preview here.
    closeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: window, queue: .main
    ) { [settings] _ in
      MainActor.assumeIsolated { settings.isPreviewingAppearance = false }
    }
    return window
  }

  private func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    let item = NSTabViewItem(viewController: controller)
    item.label = label
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    return item
  }
}

/// Remembers the last pane, so Settings reopens where it was left (HIG).
final class SettingsTabViewController: NSTabViewController {
  private static let key = "settingsSelectedTab"

  func restoreSelection() {
    let index = UserDefaults.standard.integer(forKey: Self.key)
    if tabViewItems.indices.contains(index) {
      selectedTabViewItemIndex = index
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    updateWindowTitle()
  }

  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, didSelect: tabViewItem)
    UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.key)
    updateWindowTitle()
  }

  /// The window shows the name of the open pane.
  private func updateWindowTitle() {
    guard tabViewItems.indices.contains(selectedTabViewItemIndex) else { return }
    view.window?.title = tabViewItems[selectedTabViewItemIndex].label
  }
}
