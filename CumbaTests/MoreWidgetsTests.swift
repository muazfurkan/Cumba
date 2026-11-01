import Foundation
import Testing

@testable import Cumba

struct SystemSamplerTests {
  @Test func loadIsBusyShareOfTheInterval() {
    let old = SystemSampler.CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
    let new = SystemSampler.CPUTicks(user: 160, system: 70, idle: 870, nice: 0)
    #expect(SystemSampler.cpuLoad(from: old, to: new) == 0.8)
  }

  @Test func noTimePassedMeansZero() {
    let ticks = SystemSampler.CPUTicks(user: 1, system: 1, idle: 1, nice: 0)
    #expect(SystemSampler.cpuLoad(from: ticks, to: ticks) == 0)
  }

  @Test func readsRealValuesOnThisMac() throws {
    #expect(SystemSampler.readCPUTicks() != nil)
    let memory = try #require(SystemSampler.readMemory())
    #expect(memory.used > 0 && memory.used <= memory.total)
  }
}

struct WeatherServiceTests {
  private func fixture(_ name: String) throws -> Data {
    try Data(
      contentsOf: URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "Fixtures/weather/\(name).json"))
  }

  @Test func parsesTheForecast() throws {
    let forecast = try WeatherService.parseForecast(try fixture("forecast"))
    #expect(forecast.temperature == 18.4)
    #expect(forecast.high == 21.2)
    #expect(forecast.low == 12.7)
    #expect(forecast.code == 2)
    #expect(forecast.isDay)
    #expect(forecast.unit == "°C")
    // Hours from the current one on, skipping gaps; times in the place's own zone.
    #expect(forecast.hours.count >= 6)
    #expect(forecast.hours.first?.temperature == 18.4)
    #expect(forecast.hours.first?.time == Date(timeIntervalSince1970: 1_793_469_600))
    #expect(forecast.hours[1].isDay == false)
    #expect(forecast.hours[5].temperature == 15.2)
    #expect(forecast.days.count == 6)
    #expect(forecast.days[1].code == 61)
    #expect(forecast.days[1].low == 11.9)
  }

  @Test func parsesPlaces() throws {
    let places = try WeatherService.parsePlaces(try fixture("search"))
    #expect(places.first?.label == "İstanbul, Türkiye")
    #expect(try WeatherService.parsePlaces(Data(#"{}"#.utf8)).isEmpty)
  }

  @Test func requestsCarryOnlyTheCoordinates() throws {
    let place = WeatherService.Place(name: "X", latitude: 41.0138, longitude: 28.9497)
    let url = WeatherService.forecastURL(for: place, fahrenheit: false)
    #expect(url.host() == "api.open-meteo.com")
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(query.first { $0.name == "latitude" }?.value == "41.0138")
    #expect(!url.absoluteString.contains("X"))
  }

  @Test func everyWeatherCodeHasASymbol() {
    for code in [0, 1, 2, 3, 45, 48, 51, 61, 65, 71, 80, 95, 99, 1234] {
      #expect(!WeatherService.condition(for: code, isDay: true).symbol.isEmpty)
    }
  }
}

struct ShortcutsTests {
  @Test func parsesTheListOutput() {
    let output = "Morning Routine\n  Focus  \n\nMorning Routine\nSend Location\n"
    #expect(ShortcutsWidget.parseList(output) == ["Morning Routine", "Focus", "Send Location"])
  }
}

@MainActor
struct TrayWidgetTests {
  @Test func keepsExistingFilesAndDropsDuplicates() throws {
    let suite = "TrayWidgetTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let file = FileManager.default.temporaryDirectory.appending(path: "tray-\(UUID()).txt")
    try Data("x".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    let tray = TrayWidget(defaults: defaults)
    tray.add([file, file, try #require(URL(string: "https://example.com"))])
    #expect(tray.items == [file])
    #expect(TrayWidget(defaults: defaults).items == [file])

    try FileManager.default.removeItem(at: file)
    #expect(TrayWidget(defaults: defaults).items.isEmpty)
  }
}
