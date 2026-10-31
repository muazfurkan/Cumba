import AppKit

/// Status item in the menu bar with Settings, Pause and Quit.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem: NSStatusItem
  private let settings: AppSettings
  private let onOpenSettings: @MainActor () -> Void
  private let pauseItem = NSMenuItem()

  init(settings: AppSettings, onOpenSettings: @escaping @MainActor () -> Void) {
    self.settings = settings
    self.onOpenSettings = onOpenSettings
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()
    statusItem.menu = makeMenu()
    updateButton()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    pauseItem.state = settings.isPaused ? .on : .off
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    let settingsItem = NSMenuItem(
      title: String(localized: "Settings…", comment: "Menu item that opens the Settings window"),
      action: #selector(openSettings),
      keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)

    pauseItem.title = String(localized: "Pause", comment: "Menu item that pauses the notch panel")
    pauseItem.action = #selector(togglePause)
    pauseItem.target = self
    menu.addItem(pauseItem)

    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: String(localized: "Quit ljaspNotch"),
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
    return menu
  }

  private func updateButton() {
    guard let button = statusItem.button else { return }
    let description =
      settings.isPaused
      ? String(localized: "ljaspNotch (paused)", comment: "Menu bar icon label while paused")
      : String(localized: "ljaspNotch")
    // The ljasp logo as a template image, so it follows the menu bar's colors.
    let image = NSImage(resource: .menuBarIcon)
    image.accessibilityDescription = description
    button.image = image
    button.appearsDisabled = settings.isPaused
  }

  @objc private func openSettings() {
    onOpenSettings()
  }

  @objc private func togglePause() {
    settings.isPaused.toggle()
    updateButton()
    Log.app.info("Paused: \(self.settings.isPaused, privacy: .public)")
  }
}
