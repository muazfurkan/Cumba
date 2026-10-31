import Observation
import SwiftUI

/// Current weather for a place the user picks in Settings. No location permission is used.
/// Refreshes when shown, at most every 15 minutes.
@MainActor
@Observable
final class WeatherWidget: NotchWidget {
  static let kind = "weather"
  static var title: String { String(localized: "Weather", comment: "Widget name") }
  static let symbol = "cloud.sun"
  static let size = WidgetSize.compact

  private static let placeKey = "weather.place"
  private static let refreshInterval: TimeInterval = 15 * 60

  private(set) var place: WeatherService.Place?
  private(set) var forecast: WeatherService.Forecast?
  private(set) var failed = false

  @ObservationIgnored let service = WeatherService()
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var fetchedAt: Date?
  @ObservationIgnored private let openSettings: @MainActor () -> Void

  required convenience init(context: WidgetContext) {
    self.init(context: context, defaults: .standard)
  }

  init(context: WidgetContext, defaults: UserDefaults) {
    self.defaults = defaults
    openSettings = context.openSettings
    if let data = defaults.data(forKey: Self.placeKey) {
      place = try? JSONDecoder().decode(WeatherService.Place.self, from: data)
    }
  }

  func makeView() -> AnyView {
    AnyView(WeatherView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(WeatherSettingsView(widget: self))
  }

  func activate() {
    if let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.refreshInterval {
      return
    }
    refresh()
  }

  func choose(_ place: WeatherService.Place?) {
    self.place = place
    forecast = nil
    fetchedAt = nil
    if let place, let data = try? JSONEncoder().encode(place) {
      defaults.set(data, forKey: Self.placeKey)
    } else {
      defaults.removeObject(forKey: Self.placeKey)
    }
    refresh()
  }

  func showSettings() {
    openSettings()
  }

  private func refresh() {
    guard let place else { return }
    let fahrenheit = Locale.current.measurementSystem == .us
    let service = service
    Task {
      do {
        forecast = try await service.forecast(for: place, fahrenheit: fahrenheit)
        fetchedAt = Date()
        failed = false
      } catch {
        failed = true
        Log.widgets.error("Weather request failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}

private struct WeatherView: View {
  let widget: WeatherWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 4) {
        if let place = widget.place {
          Text(place.name)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          if let forecast = widget.forecast {
            let condition = WeatherService.condition(for: forecast.code, isDay: forecast.isDay)
            Image(systemName: condition.symbol)
              .symbolRenderingMode(.multicolor)
              .font(.title2)
              .accessibilityLabel(Text(condition.text))
            Text(
              Measurement(value: forecast.temperature, unit: temperatureUnit(forecast)),
              format: .measurement(
                width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))
            )
            .font(.system(size: 22, weight: .semibold).monospacedDigit())
            if let high = forecast.high, let low = forecast.low {
              Text("↑\(Int(high.rounded()))° ↓\(Int(low.rounded()))°")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          } else if widget.failed {
            Text("Weather is unavailable.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ProgressView().controlSize(.small)
          }
        } else {
          Label("Weather", systemImage: "cloud.sun")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Choose a Place") { widget.showSettings() }
            .controlSize(.small)
        }
      }
    }
  }

  private func temperatureUnit(_ forecast: WeatherService.Forecast) -> UnitTemperature {
    forecast.unit.contains("F") ? .fahrenheit : .celsius
  }
}

private struct WeatherSettingsView: View {
  let widget: WeatherWidget
  @State private var query = ""
  @State private var results: [WeatherService.Place] = []
  @State private var searching = false
  @State private var failed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let place = widget.place {
        HStack {
          Label(place.label, systemImage: "mappin.and.ellipse")
          Spacer()
          Button("Remove") { widget.choose(nil) }
        }
      }
      HStack {
        TextField("City", text: $query)
          .onSubmit(search)
        Button("Search", action: search)
          .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
      }
      ForEach(results) { place in
        Button(place.label) {
          widget.choose(place)
          results = []
          query = ""
        }
        .buttonStyle(.link)
      }
      if failed {
        Text("The search didn't work. Check your connection.")
          .foregroundStyle(.secondary)
      }
      Text(
        "Weather data comes from Open-Meteo. Only the coordinates of the place you choose are sent."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func search() {
    let service = widget.service
    let text = query
    searching = true
    Task {
      do {
        results = try await service.search(text)
        failed = false
      } catch {
        failed = true
      }
      searching = false
    }
  }
}
