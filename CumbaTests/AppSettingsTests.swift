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

  @Test func volumeAndBrightnessShowByDefaultWithoutTheKeyTap() throws {
    let suiteName = "AppSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    #expect(settings.showsVolumeChanges)
    #expect(settings.showsBrightnessChanges)
    #expect(settings.replacesVolumeIndicator == false)
    #expect(settings.replacesBrightnessIndicator == false)
    #expect(settings.showsLowBattery)

    settings.showsVolumeChanges = false
    settings.showsBrightnessChanges = false
    let reloaded = AppSettings(defaults: defaults)
    #expect(reloaded.showsVolumeChanges == false)
    #expect(reloaded.showsBrightnessChanges == false)
  }

  @Test(arguments: [
    (20, false, true), (21, false, false), (5, true, false), (100, false, false),
  ])
  func batteryIsLowOnlyOnBatteryAtTwentyPercentOrLess(
    percent: Int, isPluggedIn: Bool, expected: Bool
  ) {
    let status = BatteryWidget.Status(
      percent: percent, isCharging: isPluggedIn, isPluggedIn: isPluggedIn)
    #expect(status.isLow == expected)
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
