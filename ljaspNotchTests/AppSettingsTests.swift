import Foundation
import Testing

@testable import ljaspNotch

@MainActor
struct AppSettingsTests {
  @Test func pausedStatePersists() throws {
    let suiteName = "AppSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    #expect(settings.isPaused == false)

    settings.isPaused = true
    #expect(AppSettings(defaults: defaults).isPaused)
  }
}
