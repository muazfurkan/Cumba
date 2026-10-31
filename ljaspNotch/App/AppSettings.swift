import Foundation
import Observation
import ServiceManagement

/// App-wide preferences, stored in UserDefaults.
@MainActor
@Observable
final class AppSettings {
  private enum Key {
    static let isPaused = "isPaused"
  }

  @ObservationIgnored private let defaults: UserDefaults

  /// While paused the notch panel stays hidden. The panel arrives in Phase 1.
  var isPaused: Bool {
    didSet { defaults.set(isPaused, forKey: Key.isPaused) }
  }

  /// Login item state as last reported by the system.
  private(set) var launchAtLogin: SMAppService.Status = .notRegistered

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    isPaused = defaults.bool(forKey: Key.isPaused)
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
