import AppKit
import SwiftUI

/// Owns the Settings window: an AppKit toolbar-style tab view whose tabs are SwiftUI views.
/// The SwiftUI `Settings` scene is not used because opening it from a menu bar item
/// needs an undocumented selector.
@MainActor
final class SettingsWindowController {
  private let settings: AppSettings
  private let themes: ThemeStore
  private var window: NSWindow?
  private var closeObserver: NSObjectProtocol?

  init(settings: AppSettings, themes: ThemeStore) {
    self.settings = settings
    self.themes = themes
  }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    Task { await settings.refreshLaunchAtLogin() }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(
      tab(
        GeneralSettingsView(settings: settings),
        label: String(localized: "General", comment: "Settings tab"),
        symbol: "gearshape"))
    tabs.addTabViewItem(
      tab(
        AppearanceSettingsView(themes: themes, settings: settings),
        label: String(localized: "Appearance", comment: "Settings tab"),
        symbol: "paintpalette"))

    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable, .miniaturizable]
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
