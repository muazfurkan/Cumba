import Foundation
import Observation
import ServiceManagement

/// App-wide preferences, stored in UserDefaults.
@MainActor
@Observable
final class AppSettings {
  private enum Key {
    static let isPaused = "isPaused"
    static let opensOnHover = "opensOnHover"
    static let openDelay = "openDelay"
    static let closeDelay = "closeDelay"
    static let hidesInFullScreen = "hidesInFullScreen"
    static let usesVirtualNotch = "usesVirtualNotch"
    static let serverPort = "serverPort"
    static let checksForUpdates = "checksForUpdates"
    static let includesPrereleases = "includesPrereleases"
    static let hapticFeedback = "hapticFeedback"
    static let hasSeenWelcome = "hasSeenWelcome"
    static let browserExtensionEnabled = "browserExtensionEnabled"
    static let notchApprovals = "notchApprovals"
    static let panelScreen = "panelScreen"
    static let tabBarStyle = "tabBarStyle"
    static let openingTab = "openingTab"
    static let widgetStyle = "widgetStyle"
    static let opensAgentTab = "opensAgentTab"
    /// Before tab bar styles: "bottom" or "top".
    static let tabBarPosition = "tabBarPosition"
    static let panelSize = "panelSize"
    static let showsVolumeChanges = "showsVolumeChanges"
    static let replacesVolumeIndicator = "replacesVolumeIndicator"
    static let showsBrightnessChanges = "showsBrightnessChanges"
    static let replacesBrightnessIndicator = "replacesBrightnessIndicator"
    static let showsPrivacyIndicators = "showsPrivacyIndicators"
    static let showsLowBattery = "showsLowBattery"
    static let scriptActivitiesEnabled = "scriptActivitiesEnabled"
  }

  /// Which display shows the panel.
  enum PanelScreen: String, CaseIterable, Sendable {
    case notched
    case main
    case pointer
  }

  /// Where the panel shows its tabs.
  /// How widgets side by side are set apart.
  enum WidgetStyle: String, CaseIterable, Sendable {
    /// No backgrounds; a faint line between widgets.
    case lines
    /// Each widget on a card of its own.
    case cards
  }

  /// Where the open panel's tabs are and how they look.
  enum TabBarStyle: String, CaseIterable, Sendable {
    /// A bar of its own under the panel; the open tab shows its name.
    case compact
    /// A bar of its own under the panel, with symbols only.
    case icons
    /// Inside the panel, at its bottom.
    case inPanel
    /// Inside the panel, beside the camera.
    case top
    /// A small bar of dots under the panel.
    case dots

    /// Drawn as a bar of its own under the panel.
    var isFloating: Bool {
      switch self {
      case .compact, .icons, .dots: true
      case .inPanel, .top: false
      }
    }
  }

  @ObservationIgnored private let defaults: UserDefaults

  /// While paused the notch panel stays hidden.
  var isPaused: Bool {
    didSet { defaults.set(isPaused, forKey: Key.isPaused) }
  }

  /// Opens the panel when the pointer rests on the notch; otherwise only a click opens it.
  var opensOnHover: Bool {
    didSet { defaults.set(opensOnHover, forKey: Key.opensOnHover) }
  }

  /// Seconds the pointer must rest on the notch before the panel opens.
  var openDelay: Double {
    didSet { defaults.set(openDelay, forKey: Key.openDelay) }
  }

  /// Seconds after the pointer leaves before the panel closes.
  var closeDelay: Double {
    didSet { defaults.set(closeDelay, forKey: Key.closeDelay) }
  }

  var hidesInFullScreen: Bool {
    didSet { defaults.set(hidesInFullScreen, forKey: Key.hidesInFullScreen) }
  }

  var panelScreen: PanelScreen {
    didSet { defaults.set(panelScreen.rawValue, forKey: Key.panelScreen) }
  }

  var tabBarStyle: TabBarStyle {
    didSet { defaults.set(tabBarStyle.rawValue, forKey: Key.tabBarStyle) }
  }

  var widgetStyle: WidgetStyle {
    didSet { defaults.set(widgetStyle.rawValue, forKey: Key.widgetStyle) }
  }

  /// The tab the panel opens on; nil opens the tab it was left on.
  var openingTab: String? {
    didSet { defaults.set(openingTab, forKey: Key.openingTab) }
  }

  /// While an agent works, the panel opens on the tab with the AI Agents widget instead.
  var opensAgentTab: Bool {
    didSet { defaults.set(opensAgentTab, forKey: Key.opensAgentTab) }
  }

  /// The panel's size and text size, the same for every theme.
  var panelSize: PanelSize {
    didSet {
      defaults.set(try? JSONEncoder().encode(panelSize), forKey: Key.panelSize)
    }
  }

  /// Draws a notch on the main screen when no screen has one.
  var usesVirtualNotch: Bool {
    didSet { defaults.set(usesVirtualNotch, forKey: Key.usesVirtualNotch) }
  }

  /// Runs the local server for the Chrome extension. Off until the user sets it up.
  var browserExtensionEnabled: Bool {
    didSet { defaults.set(browserExtensionEnabled, forKey: Key.browserExtensionEnabled) }
  }

  /// Port of the local server for the Chrome extension.
  var serverPort: UInt16 {
    didSet { defaults.set(Int(serverPort), forKey: Key.serverPort) }
  }

  /// Asks GitHub Releases for a newer version at launch and once a day.
  var checksForUpdates: Bool {
    didSet { defaults.set(checksForUpdates, forKey: Key.checksForUpdates) }
  }

  var includesPrereleases: Bool {
    didSet { defaults.set(includesPrereleases, forKey: Key.includesPrereleases) }
  }

  /// A light trackpad tap when the panel opens on hover.
  var hapticFeedback: Bool {
    didSet { defaults.set(hapticFeedback, forKey: Key.hapticFeedback) }
  }

  /// Which Claude Code requests can be allowed from the notch.
  var notchApprovals: NotchApprovals {
    didSet { defaults.set(notchApprovals.rawValue, forKey: Key.notchApprovals) }
  }

  /// Shows the level beside the notch when the volume changes.
  var showsVolumeChanges: Bool {
    didSet { defaults.set(showsVolumeChanges, forKey: Key.showsVolumeChanges) }
  }

  /// Handles the volume keys so the system indicator doesn't appear (needs Accessibility).
  var replacesVolumeIndicator: Bool {
    didSet { defaults.set(replacesVolumeIndicator, forKey: Key.replacesVolumeIndicator) }
  }

  /// Shows the level beside the notch when the built-in display's brightness changes.
  var showsBrightnessChanges: Bool {
    didSet { defaults.set(showsBrightnessChanges, forKey: Key.showsBrightnessChanges) }
  }

  /// Handles the brightness keys so the system indicator doesn't appear (needs
  /// Accessibility).
  var replacesBrightnessIndicator: Bool {
    didSet { defaults.set(replacesBrightnessIndicator, forKey: Key.replacesBrightnessIndicator) }
  }

  /// Shows a dot while any app uses a microphone or a camera.
  var showsPrivacyIndicators: Bool {
    didSet { defaults.set(showsPrivacyIndicators, forKey: Key.showsPrivacyIndicators) }
  }

  /// Shows the battery beside the notch while it's low and the charger isn't plugged in.
  var showsLowBattery: Bool {
    didSet { defaults.set(showsLowBattery, forKey: Key.showsLowBattery) }
  }

  /// Lets local scripts show activities through `/activity` on the private socket.
  var scriptActivitiesEnabled: Bool {
    didSet { defaults.set(scriptActivitiesEnabled, forKey: Key.scriptActivitiesEnabled) }
  }

  /// Set once the welcome window has been shown.
  var hasSeenWelcome: Bool {
    didSet { defaults.set(hasSeenWelcome, forKey: Key.hasSeenWelcome) }
  }

  /// True while the Appearance settings are visible; the panel stays open as a live preview.
  /// Not saved.
  var isPreviewingAppearance = false
  /// While a size slider for the closed notch or the space beside it is dragged, the
  /// preview shows that state instead of the open panel. Not saved.
  var notchPreview: NotchPreview?

  /// Login item state as last reported by the system.
  private(set) var launchAtLogin: SMAppService.Status = .notRegistered

  static let openDelayRange = 0.0...1.0
  static let closeDelayRange = 0.0...2.0

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    isPaused = defaults.bool(forKey: Key.isPaused)
    opensOnHover = defaults.object(forKey: Key.opensOnHover) as? Bool ?? true
    openDelay = defaults.object(forKey: Key.openDelay) as? Double ?? 0.15
    closeDelay = defaults.object(forKey: Key.closeDelay) as? Double ?? 0.4
    hidesInFullScreen = defaults.object(forKey: Key.hidesInFullScreen) as? Bool ?? true
    usesVirtualNotch = defaults.bool(forKey: Key.usesVirtualNotch)
    let port = defaults.integer(forKey: Key.serverPort)
    serverPort = (1024...65535).contains(port) ? UInt16(port) : LocalServer.defaultPort
    checksForUpdates = defaults.object(forKey: Key.checksForUpdates) as? Bool ?? true
    includesPrereleases = defaults.bool(forKey: Key.includesPrereleases)
    hapticFeedback = defaults.object(forKey: Key.hapticFeedback) as? Bool ?? true
    hasSeenWelcome = defaults.bool(forKey: Key.hasSeenWelcome)
    browserExtensionEnabled = defaults.bool(forKey: Key.browserExtensionEnabled)
    notchApprovals =
      defaults.string(forKey: Key.notchApprovals).flatMap(NotchApprovals.init(rawValue:)) ?? .all
    panelScreen =
      defaults.string(forKey: Key.panelScreen).flatMap(PanelScreen.init(rawValue:)) ?? .notched
    tabBarStyle =
      defaults.string(forKey: Key.tabBarStyle).flatMap(TabBarStyle.init(rawValue:))
      ?? Self.legacyTabBarStyle(defaults.string(forKey: Key.tabBarPosition))
    openingTab = defaults.string(forKey: Key.openingTab)
    widgetStyle =
      defaults.string(forKey: Key.widgetStyle).flatMap(WidgetStyle.init(rawValue:)) ?? .lines
    opensAgentTab = defaults.object(forKey: Key.opensAgentTab) as? Bool ?? true
    panelSize =
      defaults.data(forKey: Key.panelSize).flatMap {
        try? JSONDecoder().decode(PanelSize.self, from: $0)
      } ?? PanelSize()
    showsVolumeChanges = defaults.object(forKey: Key.showsVolumeChanges) as? Bool ?? true
    replacesVolumeIndicator = defaults.bool(forKey: Key.replacesVolumeIndicator)
    showsBrightnessChanges = defaults.object(forKey: Key.showsBrightnessChanges) as? Bool ?? true
    replacesBrightnessIndicator = defaults.bool(forKey: Key.replacesBrightnessIndicator)
    showsPrivacyIndicators = defaults.bool(forKey: Key.showsPrivacyIndicators)
    showsLowBattery = defaults.object(forKey: Key.showsLowBattery) as? Bool ?? true
    scriptActivitiesEnabled = defaults.bool(forKey: Key.scriptActivitiesEnabled)
  }

  /// The style matching a tab position chosen before there were styles; new installations
  /// get the compact bar.
  static func legacyTabBarStyle(_ position: String?) -> TabBarStyle {
    switch position {
    case "top": .top
    case "bottom": .inPanel
    default: .compact
    }
  }

  /// Takes the size a theme file carried before size became a setting, once: only while no
  /// size has been saved.
  func adoptLegacyPanelSize(_ size: PanelSize?) {
    guard let size, defaults.data(forKey: Key.panelSize) == nil else { return }
    panelSize = size
  }

  /// Registers or removes the login item. Runs off the main thread because it
  /// waits on a system daemon.
  func setLaunchAtLogin(_ enabled: Bool) async {
    launchAtLogin = await Task.detached {
      let service = SMAppService.mainApp
      do {
        if enabled {
          try service.register()
        } else {
          try service.unregister()
        }
      } catch {
        Log.settings.error(
          "Login item update failed: \(error.localizedDescription, privacy: .public)")
      }
      return service.status
    }.value
  }

  func refreshLaunchAtLogin() async {
    launchAtLogin = await Task.detached { SMAppService.mainApp.status }.value
  }
}

/// What the Appearance preview shows while a size slider is dragged.
enum NotchPreview: Sendable {
  /// The closed notch, even while something shows beside it.
  case closed
  /// Something beside the notch, a sample if nothing is there.
  case peek
}
