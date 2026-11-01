import AppKit
import SwiftUI

/// Owns the Settings window: a sidebar of pages, like System Settings, hosted from SwiftUI.
/// The SwiftUI `Settings` scene is not used because opening it from a menu bar item
/// needs an undocumented selector.
@MainActor
final class SettingsWindowController {
  private let settings: AppSettings
  private let themes: ThemeStore
  private let layoutStore: LayoutStore
  private let registry: WidgetRegistry
  private let server: LocalServer
  private let updates: UpdateChecker
  private let navigation = SettingsNavigation()
  private var window: NSWindow?
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

  func show(page: SettingsPage? = nil) {
    let window = window ?? makeWindow()
    self.window = window
    if let page {
      navigation.search = ""
      navigation.page = page
    }
    Task { await settings.refreshLaunchAtLogin() }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let root = SettingsRootView(
      navigation: navigation, settings: settings, themes: themes, layoutStore: layoutStore,
      registry: registry, server: server, updates: updates,
      diagnostics: Diagnostics.Sources(
        settings: settings, themes: themes, layout: layoutStore, server: server))
    let controller = NSHostingController(rootView: root)
    // The page title and the sidebar button go into the window's toolbar.
    controller.sceneBridgingOptions = [.title, .toolbars]
    let window = NSWindow(contentViewController: controller)
    // Settings windows have no minimize button (HIG).
    window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
    window.toolbar = NSToolbar(identifier: "Settings")
    window.toolbarStyle = .unified
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 820, height: 640))
    window.contentMinSize = NSSize(width: 700, height: 480)
    // While this app is active, pointer moves reach the notch hover tracker only
    // through this window.
    window.acceptsMouseMovedEvents = true
    window.center()
    window.setFrameAutosaveName("SettingsWindow")
    // SwiftUI doesn't always report onDisappear when the window closes; end the preview here.
    closeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: window, queue: .main
    ) { [settings] _ in
      MainActor.assumeIsolated {
        settings.isPreviewingAppearance = false
        settings.notchPreview = nil
      }
    }
    return window
  }
}
