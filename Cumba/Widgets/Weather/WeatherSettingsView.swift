import SwiftUI

/// Settings > Widgets > Weather: the Mac's location or a city found by name.
struct WeatherSettingsView: View {
  let widget: WeatherWidget
  @State private var query = ""
  @State private var results: [WeatherService.Place] = []
  @State private var searching = false
  @State private var failed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(
        "Use my current location",
        isOn: Binding(
          get: { widget.usesCurrentLocation }, set: { widget.setUsesCurrentLocation($0) }))
      if widget.usesCurrentLocation {
        currentLocation
      } else {
        citySearch
      }
      Text(
        "Weather data comes from Open-Meteo. Your location is rounded to about 10 km before it's sent, and Apple Maps finds the city name. For a chosen city, only its coordinates are sent."
      )
      .panelFont(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder private var currentLocation: some View {
    switch widget.locationAccess {
    case .allowed:
      if let place = widget.currentPlace {
        Label(place.name, systemImage: "location.fill")
      } else {
        Label("Finding your location…", systemImage: "location")
          .foregroundStyle(.secondary)
      }
    case .notAsked:
      Button("Allow Location Access…") { widget.requestLocationAccess() }
    case .denied:
      HStack {
        Text("Location access is off for Cumba.")
          .foregroundStyle(.secondary)
        Spacer()
        OpenPrivacySettings(pane: "Privacy_LocationServices")
      }
    }
  }

  @ViewBuilder private var citySearch: some View {
    if let place = widget.chosenPlace {
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
