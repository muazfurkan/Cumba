import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let settings: AppSettings
  private let themes: ThemeStore
  private let liveActivities: LiveActivityCenter
  private let media: MediaCoordinator
  private let server: LocalServer
  private let claude: ClaudeCodeService
  private let updates: UpdateChecker
  private let registry: WidgetRegistry
  private let layoutStore: LayoutStore
  private let settingsWindow: SettingsWindowController
  private let welcomeWindow: WelcomeWindowController
  private let notchWindow: NotchWindowController
  private var menuBar: MenuBarController?

  override init() {
    settings = AppSettings()
    themes = ThemeStore()
    liveActivities = LiveActivityCenter()
    media = MediaCoordinator.standard()
    claude = ClaudeCodeService(liveActivities: liveActivities)
    updates = UpdateChecker(settings: settings)
    server = LocalServer(browserHub: BrowserMediaHub(), claude: claude)
    // Widgets are created before the Settings window, so they reach it through this box.
    let settingsOpener = SettingsOpener()
    let panelControl = PanelControl()
    registry = WidgetRegistry.standard(
      context: WidgetContext(
        liveActivities: liveActivities, media: media, claude: claude, panel: panelControl,
        openSettings: { settingsOpener.open($0) }))
    layoutStore = LayoutStore(
      knownKinds: registry.infos.map { ($0.kind, $0.size.units) },
      defaultKinds: Set(registry.infos.filter(\.addedByDefault).map(\.kind)))
    settingsWindow = SettingsWindowController(
      settings: settings, themes: themes, layoutStore: layoutStore, registry: registry,
      server: server, updates: updates)
    welcomeWindow = WelcomeWindowController(settings: settings) { [settingsWindow] in
      settingsWindow.show()
    }
    notchWindow = NotchWindowController(
      settings: settings, themes: themes, panelControl: panelControl,
      host: WidgetHost(
        layoutStore: layoutStore, registry: registry, liveActivities: liveActivities,
        claude: claude))
    super.init()
    settingsOpener.open = { [notchWindow, settingsWindow] tab in
      // Close the panel first so permission prompts can't end up behind it.
      notchWindow.collapse()
      settingsWindow.show(tab: tab)
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    notchWindow.openSettings = { [settingsWindow] in settingsWindow.show() }
    NSApp.mainMenu = MainMenu.make()
    menuBar = MenuBarController(settings: settings, updates: updates) { [settingsWindow] in
      settingsWindow.show()
    }
    updates.start()
    observeUpdateSetting()
    media.start()
    media.add(server.browserHub.youtube)
    media.add(server.browserHub.youtubeMusic)
    observeApprovals()
    Task { [server, settings] in
      await server.loadTokens()
      if settings.browserExtensionEnabled {
        server.startExtensionServer(port: settings.serverPort)
      }
      // The hook socket runs only while hooks are installed (or left over from an update).
      let token = server.hookToken
      let hooksPresent = await Task.detached {
        (try? HookInstaller.standard.status(token: token)).map { $0 != .notInstalled } ?? false
      }.value
      if hooksPresent {
        server.startHookServer()
      }
    }
    notchWindow.start()
    Task { [themes, layoutStore] in
      await themes.load()
      await layoutStore.load()
    }
    welcomeWindow.showIfFirstLaunch()
    Log.app.info(
      "Launched version \(AppInfo.version, privacy: .public) (\(AppInfo.build, privacy: .public))")
  }

  private func observeApprovals() {
    claude.notchApprovals = settings.notchApprovals
    withObservationTracking {
      _ = settings.notchApprovals
    } onChange: { [weak self] in
      Task { @MainActor in self?.observeApprovals() }
    }
  }

  private func observeUpdateSetting() {
    withObservationTracking {
      _ = settings.checksForUpdates
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.settings.checksForUpdates ? self.updates.start() : self.updates.stop()
        self.observeUpdateSetting()
      }
    }
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
  var open: (SettingsWindowController.Tab) -> Void = { _ in }
}
