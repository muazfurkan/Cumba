import AppKit
import SwiftUI

/// The window shown on first launch. A menu bar app shows nothing else when it starts, and
/// its icon can hide behind the notch, so this explains how to open the panel and where
/// Settings are, and asks to move the app to Applications when it runs from elsewhere.
@MainActor
final class WelcomeWindowController {
  private let settings: AppSettings
  private let openSettings: @MainActor () -> Void
  private var window: NSWindow?

  init(settings: AppSettings, openSettings: @escaping @MainActor () -> Void) {
    self.settings = settings
    self.openSettings = openSettings
  }

  /// Shows the window once per installation.
  func showIfFirstLaunch() {
    guard !settings.hasSeenWelcome else { return }
    settings.hasSeenWelcome = true
    show()
  }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    Task { await settings.refreshLaunchAtLogin() }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let view = WelcomeView(
      settings: settings,
      isInApplications: AppInfo.isInApplicationsFolder(Bundle.main.bundleURL),
      openSettings: { [weak self] in
        self?.window?.close()
        self?.openSettings()
      },
      close: { [weak self] in self?.window?.close() })
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    let window = NSWindow(contentViewController: controller)
    window.styleMask = [.titled, .closable, .fullSizeContentView]
    window.title = String(localized: "Welcome to ljaspNotch", comment: "Welcome window title")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }
}
