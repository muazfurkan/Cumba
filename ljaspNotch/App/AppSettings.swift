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
  }

  /// Which display shows the panel.
  enum PanelScreen: String, CaseIterable, Sendable {
    case notched
    case main
    case pointer
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

  /// Set once the welcome window has been shown.
  var hasSeenWelcome: Bool {
    didSet { defaults.set(hasSeenWelcome, forKey: Key.hasSeenWelcome) }
  }

  /// True while the Appearance settings are visible; the panel stays open as a live preview.
  /// Not saved.
  var isPreviewingAppearance = false

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
