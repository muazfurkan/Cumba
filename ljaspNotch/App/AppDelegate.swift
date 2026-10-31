import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let settings: AppSettings
  private let settingsWindow: SettingsWindowController
  private let notchWindow: NotchWindowController
  private var menuBar: MenuBarController?

  override init() {
    settings = AppSettings()
    settingsWindow = SettingsWindowController(settings: settings)
    notchWindow = NotchWindowController(settings: settings)
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.make()
    menuBar = MenuBarController(settings: settings) { [settingsWindow] in
      settingsWindow.show()
    }
    notchWindow.start()
    Log.app.info(
      "Launched version \(AppInfo.version, privacy: .public) (\(AppInfo.build, privacy: .public))")
  }

  // Opening the app again from Finder or Spotlight shows Settings, because the
  // menu bar icon can end up hidden behind the notch when the menu bar is crowded.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    settingsWindow.show()
    return false
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}
