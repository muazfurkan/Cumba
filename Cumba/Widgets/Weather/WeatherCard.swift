import SwiftUI

/// The forecast in the style of Apple's Weather widget: a sky-colored card with the place,
/// the temperature and the coming days. Alone in its tab it adds the next hours.
struct WeatherCard: View {
  let place: WeatherService.Place
  let forecast: WeatherService.Forecast
  let isCurrentLocation: Bool
  @Environment(\.showsDetailedWidget) private var isDetailed

  var body: some View {
    let condition = WeatherService.condition(for: forecast.code, isDay: forecast.isDay)
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 4) {
            Text(place.name)
              .panelFont(.callout, weight: .semibold)
              .lineLimit(1)
            if isCurrentLocation {
              Image(systemName: "location.fill")
                .panelFont(.caption2)
                .accessibilityLabel(Text("Current location"))
            }
          }
          Text(degrees(forecast.temperature))
            .panelFont(size: 34, weight: .light)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
        }
        Spacer(minLength: 6)
        VStack(alignment: .trailing, spacing: 2) {
          Image(systemName: condition.symbol)
            .symbolRenderingMode(.multicolor)
            .panelFont(.title3)
            .accessibilityHidden(true)
          Text(condition.text)
            .panelFont(.caption, weight: .medium)
            .lineLimit(1)
          if let high = forecast.high, let low = forecast.low {
            Text("H:\(degrees(high)) L:\(degrees(low))", comment: "Today's high and low")
              .panelFont(.caption, monospacedDigit: true)
              .lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
      if isDetailed {
        HStack(alignment: .bottom, spacing: 14) {
          row(hours)
          Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 44)
          row(days)
        }
      } else {
        row(days)
      }
    }
    .foregroundStyle(.white)
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      Self.sky(code: forecast.code, isDay: forecast.isDay),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
  }

  private var hours: [Column] {
    forecast.hours.prefix(6).enumerated().map { index, hour in
      Column(
        id: hour.time,
        label: index == 0
          ? String(localized: "Now", comment: "Weather: the current hour")
          : hour.time.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated))),
        symbol: WeatherService.condition(for: hour.code, isDay: hour.isDay).symbol,
        value: degrees(hour.temperature))
    }
  }

  /// The next five days; the weekday short and in the user's language.
  private var days: [Column] {
    forecast.days.dropFirst().prefix(5).map { day in
      Column(
        id: day.date,
        label: day.date.formatted(.dateTime.weekday(.abbreviated)),
        symbol: WeatherService.condition(for: day.code, isDay: true).symbol,
        value: day.high.map(degrees) ?? "–")
    }
  }

  private struct Column: Identifiable {
    let id: Date
    let label: String
    let symbol: String
    let value: String
  }

  private func row(_ columns: [Column]) -> some View {
    HStack(spacing: 0) {
      ForEach(columns) { column in
        VStack(spacing: 3) {
          Text(column.label)
            .panelFont(.caption2, weight: .medium)
            .minimumScaleFactor(0.7)
            .opacity(0.85)
          Image(systemName: column.symbol)
            .symbolRenderingMode(.multicolor)
            .panelFont(.caption)
            .frame(height: 14)
            .accessibilityHidden(true)
          Text(column.value)
            .panelFont(.caption, weight: .medium, monospacedDigit: true)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func degrees(_ value: Double) -> String {
    "\(Int(value.rounded()))°"
  }

  /// Sky colors by condition and time of day, like Apple's Weather.
  static func sky(code: Int, isDay: Bool) -> LinearGradient {
    let colors: (Color, Color) =
      switch (code, isDay) {
      case (0...1, true):
        (Color(red: 0.20, green: 0.48, blue: 0.86), Color(red: 0.42, green: 0.66, blue: 0.93))
      case (0...1, false):
        (Color(red: 0.05, green: 0.09, blue: 0.24), Color(red: 0.17, green: 0.23, blue: 0.42))
      case (2...3, true), (45...48, true):
        (Color(red: 0.35, green: 0.47, blue: 0.62), Color(red: 0.55, green: 0.65, blue: 0.76))
      case (2...3, false), (45...48, false):
        (Color(red: 0.13, green: 0.17, blue: 0.27), Color(red: 0.27, green: 0.32, blue: 0.42))
      case (95...99, _):
        (Color(red: 0.16, green: 0.17, blue: 0.29), Color(red: 0.31, green: 0.32, blue: 0.45))
      case (71...86, _):
        (Color(red: 0.44, green: 0.53, blue: 0.64), Color(red: 0.68, green: 0.75, blue: 0.83))
      case (_, true):
        (Color(red: 0.27, green: 0.36, blue: 0.48), Color(red: 0.42, green: 0.52, blue: 0.63))
      case (_, false):
        (Color(red: 0.11, green: 0.14, blue: 0.21), Color(red: 0.22, green: 0.27, blue: 0.36))
      }
    return LinearGradient(colors: [colors.0, colors.1], startPoint: .top, endPoint: .bottom)
  }
}
