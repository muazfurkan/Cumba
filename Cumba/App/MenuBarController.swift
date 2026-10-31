import AppKit

/// Status item in the menu bar with Settings, Pause and Quit.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem: NSStatusItem
  private let settings: AppSettings
  private let onOpenSettings: @MainActor () -> Void
  private let updates: UpdateChecker
  private let pauseItem = NSMenuItem()
  private let updateItem = NSMenuItem()

  init(
    settings: AppSettings, updates: UpdateChecker,
    onOpenSettings: @escaping @MainActor () -> Void
  ) {
    self.settings = settings
    self.updates = updates
    self.onOpenSettings = onOpenSettings
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()
    statusItem.menu = makeMenu()
    updateButton()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    pauseItem.state = settings.isPaused ? .on : .off
    if let release = updates.available {
      updateItem.title = String(
        localized: "Update Available: \(release.version)…", comment: "Menu item")
      updateItem.isHidden = false
    } else {
      updateItem.isHidden = true
    }
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    updateItem.action = #selector(openUpdate)
    updateItem.target = self
    updateItem.isHidden = true
    menu.addItem(updateItem)

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
        title: String(localized: "Quit Cumba"),
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
    return menu
  }

  private func updateButton() {
    guard let button = statusItem.button else { return }
    let description =
      settings.isPaused
      ? String(localized: "Cumba (paused)", comment: "Menu bar icon label while paused")
      : String(localized: "Cumba")
    // The logo as a template image, so it follows the menu bar's colors.
    let image = NSImage(resource: .menuBarIcon)
    image.accessibilityDescription = description
    button.image = image
    button.appearsDisabled = settings.isPaused
  }

  @objc private func openUpdate() {
    if let url = updates.available?.url {
      NSWorkspace.shared.open(url)
    }
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
