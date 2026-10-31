import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let settings: AppSettings
  private let themes: ThemeStore
  private let liveActivities: LiveActivityCenter
  private let media: MediaCoordinator
  private let server: LocalServer
  private let claude: ClaudeCodeService
  private let registry: WidgetRegistry
  private let layoutStore: LayoutStore
  private let settingsWindow: SettingsWindowController
  private let notchWindow: NotchWindowController
  private var menuBar: MenuBarController?

  override init() {
    settings = AppSettings()
    themes = ThemeStore()
    liveActivities = LiveActivityCenter()
    media = MediaCoordinator.standard()
    claude = ClaudeCodeService(liveActivities: liveActivities)
    server = LocalServer(browserHub: BrowserMediaHub(), claude: claude)
    // Widgets are created before the Settings window, so they reach it through this box.
    let settingsOpener = SettingsOpener()
    registry = WidgetRegistry.standard(
      context: WidgetContext(
        liveActivities: liveActivities, media: media, claude: claude,
        openSettings: { settingsOpener.open() }))
    layoutStore = LayoutStore(knownKinds: registry.kinds)
    settingsWindow = SettingsWindowController(
      settings: settings, themes: themes, layoutStore: layoutStore, registry: registry,
      server: server)
    notchWindow = NotchWindowController(
      settings: settings, themes: themes,
      host: WidgetHost(
        layoutStore: layoutStore, registry: registry, liveActivities: liveActivities,
        claude: claude))
    super.init()
    settingsOpener.open = { [notchWindow, settingsWindow] in
      // Close the panel first so permission prompts can't end up behind it.
      notchWindow.collapse()
      settingsWindow.show(tab: .widgets)
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.make()
    menuBar = MenuBarController(settings: settings) { [settingsWindow] in
      settingsWindow.show()
    }
    media.start()
    media.add(server.browserHub.youtube)
    media.add(server.browserHub.youtubeMusic)
    Task { [server, settings] in await server.start(port: settings.serverPort) }
    notchWindow.start()
    Task { [themes, layoutStore] in
      await themes.load()
      await layoutStore.load()
    }
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

/// Holds the action that opens Settings once the window controller exists.
@MainActor
private final class SettingsOpener {
  var open: () -> Void = {}
}
