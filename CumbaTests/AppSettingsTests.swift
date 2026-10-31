import Foundation
import Testing

@testable import Cumba

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

@MainActor
struct WelcomeTests {
  @Test func welcomeIsShownOnce() throws {
    let suiteName = "WelcomeTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    #expect(settings.hasSeenWelcome == false)
    settings.hasSeenWelcome = true
    #expect(AppSettings(defaults: defaults).hasSeenWelcome)
  }

  @Test(arguments: [
    ("/Applications/Cumba.app", true),
    ("/Applications/Utilities/Cumba.app", true),
    ("/Users/someone/Applications/Cumba.app", true),
    ("/Users/someone/Downloads/Cumba.app", false),
    ("/private/var/folders/x/AppTranslocation/1234/d/Cumba.app", false),
    ("/Applications Old/Cumba.app", false),
  ])
  func detectsTheApplicationsFolder(path: String, expected: Bool) {
    let home = URL(filePath: "/Users/someone", directoryHint: .isDirectory)
    #expect(
      AppInfo.isInApplicationsFolder(URL(filePath: path, directoryHint: .isDirectory), home: home)
        == expected)
  }
}
