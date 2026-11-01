import AppKit
import Observation
import SwiftUI

/// Current weather where the Mac is (Location Services, rounded to about 10 km) or for a
/// place the user picks in Settings. Refreshes when shown, at most every 15 minutes.
@MainActor
@Observable
final class WeatherWidget: NotchWidget {
  static let kind = "weather"
  static var title: String { String(localized: "Weather", comment: "Widget name") }
  static let symbol = "cloud.sun"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "Current weather where you are, or for a place you choose",
      comment: "Widget description")
  }

  private static let placeKey = "weather.place"
  private static let currentLocationKey = "weather.usesCurrentLocation"
  private static let refreshInterval: TimeInterval = 15 * 60

  /// Follows the Mac's location instead of `chosenPlace`. On by default, unless a place
  /// was chosen before this option existed.
  private(set) var usesCurrentLocation: Bool
  private(set) var chosenPlace: WeatherService.Place?
  /// The Mac's location with its city name, once found.
  private(set) var currentPlace: WeatherService.Place?
  private(set) var locationAccess: LocationProvider.Access
  private(set) var forecast: WeatherService.Forecast?
  private(set) var failed = false

  /// The place the forecast is for.
  var place: WeatherService.Place? { usesCurrentLocation ? currentPlace : chosenPlace }

  @ObservationIgnored let service = WeatherService()
  @ObservationIgnored private let location = LocationProvider()
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var fetchedAt: Date?
  /// On screen in the open panel (or its settings), between `activate` and `deactivate`.
  @ObservationIgnored private var isActive = false
  @ObservationIgnored private let openSettings: @MainActor (SettingsPage) -> Void
  @ObservationIgnored private let panel: PanelControl

  required convenience init(context: WidgetContext) {
    self.init(context: context, defaults: .standard)
  }

  init(context: WidgetContext, defaults: UserDefaults) {
    self.defaults = defaults
    openSettings = context.openSettings
    panel = context.panel
    let saved = defaults.data(forKey: Self.placeKey).flatMap {
      try? JSONDecoder().decode(WeatherService.Place.self, from: $0)
    }
    chosenPlace = saved
    usesCurrentLocation =
      defaults.object(forKey: Self.currentLocationKey) as? Bool ?? (saved == nil)
    locationAccess = location.access
    // Called once at launch too: only fetch while the widget is on screen.
    location.onAccessChange = { [weak self] in
      guard let self else { return }
      locationAccess = location.access
      if isActive {
        reload()
      } else {
        fetchedAt = nil
      }
    }
  }

  func makeView() -> AnyView {
    AnyView(WeatherView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(WeatherSettingsView(widget: self))
  }

  func activate() {
    isActive = true
    if let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.refreshInterval {
      return
    }
    refresh()
  }

  func deactivate() {
    isActive = false
  }

  func choose(_ place: WeatherService.Place?) {
    chosenPlace = place
    if let place, let data = try? JSONEncoder().encode(place) {
      defaults.set(data, forKey: Self.placeKey)
      setUsesCurrentLocation(false)
    } else {
      defaults.removeObject(forKey: Self.placeKey)
      reload()
    }
  }

  func setUsesCurrentLocation(_ uses: Bool) {
    usesCurrentLocation = uses
    defaults.set(uses, forKey: Self.currentLocationKey)
    reload()
  }

  /// From the panel: closes it first so the system prompt can't end up behind it.
  func useMyLocation() {
    panel.close()
    requestLocationAccess()
  }

  func requestLocationAccess() {
    NSApp.activate()
    Task {
      locationAccess = await location.requestAccess()
      setUsesCurrentLocation(true)
    }
  }

  func showSettings() {
    openSettings(.widget(Self.kind))
  }

  /// Forgets the last forecast and fetches again.
  private func reload() {
    forecast = nil
    fetchedAt = nil
    failed = false
    refresh()
  }

  private func refresh() {
    let fahrenheit = Locale.current.measurementSystem == .us
    let service = service
    Task {
      if usesCurrentLocation {
        locationAccess = location.access
        guard locationAccess == .allowed else { return }
        await findCurrentPlace()
      }
      guard let place else {
        failed = usesCurrentLocation
        return
      }
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

  /// Looks up the city name only when the rounded location changed.
  private func findCurrentPlace() async {
    guard let fix = await location.approximateLocation() else { return }
    let latitude = fix.coordinate.latitude
    let longitude = fix.coordinate.longitude
    if let currentPlace, currentPlace.latitude == latitude, currentPlace.longitude == longitude {
      return
    }
    let city = await LocationProvider.cityName(at: fix)
    currentPlace = WeatherService.Place(
      name: city ?? String(localized: "My Location", comment: "Weather place without a name"),
      latitude: latitude, longitude: longitude)
  }
}

private struct WeatherView: View {
  let widget: WeatherWidget

  var body: some View {
    if let place = widget.place, let forecast = widget.forecast {
      WeatherCard(
        place: place, forecast: forecast, isCurrentLocation: widget.usesCurrentLocation)
    } else {
      setupCard
    }
  }

  private var setupCard: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 4) {
        if let place = widget.place {
          Text(place.name)
            .panelFont(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          if widget.failed {
            Text("Weather is unavailable.")
              .panelFont(.caption)
              .foregroundStyle(.secondary)
          } else {
            ProgressView().controlSize(.small)
          }
        } else {
          WidgetHeader("Weather", symbol: "cloud.sun", color: .blue)
          setup
        }
      }
    }
  }

  @ViewBuilder private var setup: some View {
    if !widget.usesCurrentLocation {
      Button("Choose a Place") { widget.showSettings() }
        .controlSize(.small)
    } else {
      switch widget.locationAccess {
      case .notAsked:
        Button("Use My Location") { widget.useMyLocation() }
          .controlSize(.small)
        chooseCity
      case .denied:
        Text("Location access is off.")
          .panelFont(.caption)
          .foregroundStyle(.secondary)
        chooseCity
      case .allowed:
        if widget.failed {
          Text("Your location couldn't be found.")
            .panelFont(.caption)
            .foregroundStyle(.secondary)
          chooseCity
        } else {
          ProgressView().controlSize(.small)
        }
      }
    }
  }

  private var chooseCity: some View {
    Button("Choose a City") { widget.showSettings() }
      .buttonStyle(.plain)
      .panelFont(.caption2)
      .foregroundStyle(.secondary)
  }
}
