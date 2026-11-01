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

  @Test func panelSizePersistsAndTakesAnOldThemeSizeOnce() throws {
    let suiteName = "AppSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    #expect(settings.panelSize == PanelSize())
    var old = PanelSize()
    old.width = 800
    settings.adoptLegacyPanelSize(old)
    #expect(settings.panelSize.width == 800)

    var other = PanelSize()
    other.width = 500
    settings.adoptLegacyPanelSize(other)
    #expect(settings.panelSize.width == 800)

    settings.panelSize.textScale = 1.4
    let reloaded = AppSettings(defaults: defaults)
    #expect(reloaded.panelSize.width == 800)
    #expect(reloaded.panelSize.textScale == 1.4)
  }

  @Test func invalidPanelSizeValuesFallBack() throws {
    let data = Data(#"{ "width": 5000, "height": "tall", "textScale": 0.1 }"#.utf8)
    let size = try JSONDecoder().decode(PanelSize.self, from: data)
    #expect(size.width == PanelSize.widthRange.upperBound)
    #expect(size.height == PanelSize().height)
    #expect(size.textScale == PanelSize.textScaleRange.lowerBound)
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
