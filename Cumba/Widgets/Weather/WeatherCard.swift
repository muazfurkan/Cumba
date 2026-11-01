import SwiftUI

/// The forecast in the style of Apple's Weather widget: a sky-colored card with the place,
/// the temperature and the coming days. Clicking a day shows that day; alone in its tab it
/// adds a row of hours that scrolls sideways.
struct WeatherCard: View {
  let place: WeatherService.Place
  let forecast: WeatherService.Forecast
  let isCurrentLocation: Bool
  @Environment(\.showsDetailedWidget) private var isDetailed
  /// A coming day picked from the row; nil shows now.
  @State private var pickedDay: Date?

  private var picked: WeatherService.Day? {
    forecast.days.first { $0.date == pickedDay }
  }

  var body: some View {
    let code = picked?.code ?? forecast.code
    let condition = WeatherService.condition(
      for: code, isDay: picked == nil ? forecast.isDay : true)
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 4) {
            Text(picked.map { $0.date.formatted(.dateTime.weekday(.wide)) } ?? place.name)
              .panelFont(.callout, weight: .semibold)
              .lineLimit(1)
            if isCurrentLocation && picked == nil {
              Image(systemName: "location.fill")
                .panelFont(.caption2)
                .accessibilityLabel(Text("Current location"))
            }
          }
          Text(degrees(picked?.high ?? forecast.temperature))
            .panelFont(size: 34, weight: .light)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .contentTransition(.numericText())
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
          if let high = picked?.high ?? forecast.high, let low = picked?.low ?? forecast.low {
            Text("H:\(degrees(high)) L:\(degrees(low))", comment: "Today's high and low")
              .panelFont(.caption, monospacedDigit: true)
              .lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
      if isDetailed {
        HStack(alignment: .bottom, spacing: 14) {
          HourRow(columns: hours)
          Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 44)
          dayRow
        }
      } else {
        dayRow
      }
    }
    .foregroundStyle(.white)
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      Self.sky(code: code, isDay: picked == nil ? forecast.isDay : true),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .animation(.smooth(duration: 0.25), value: pickedDay)
    .accessibilityElement(children: .contain)
  }

  /// The picked day's hours, or the next 24 from now.
  private var hours: [Column] {
    let calendar = Calendar.current
    let shown =
      pickedDay.map { day in forecast.hours.filter { calendar.isDate($0.time, inSameDayAs: day) } }
      ?? Array(forecast.hours.prefix(24))
    return shown.enumerated().map { index, hour in
      Column(
        id: hour.time,
        label: index == 0 && pickedDay == nil
          ? String(localized: "Now", comment: "Weather: the current hour")
          : hour.time.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated))),
        symbol: WeatherService.condition(for: hour.code, isDay: hour.isDay).symbol,
        value: degrees(hour.temperature))
    }
  }

  /// The next five days; clicking one shows it, clicking it again goes back to now.
  private var dayRow: some View {
    HStack(spacing: 0) {
      ForEach(forecast.days.dropFirst().prefix(5)) { day in
        let isPicked = day.date == pickedDay
        Button {
          pickedDay = isPicked ? nil : day.date
        } label: {
          ColumnView(
            column: Column(
              id: day.date,
              label: day.date.formatted(.dateTime.weekday(.abbreviated)),
              symbol: WeatherService.condition(for: day.code, isDay: true).symbol,
              value: day.high.map(degrees) ?? "–")
          )
          .padding(.vertical, 2)
          .background {
            if isPicked {
              RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.2))
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
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

private struct Column: Identifiable {
  let id: Date
  let label: String
  let symbol: String
  let value: String
}

private struct ColumnView: View {
  let column: Column

  var body: some View {
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
    .accessibilityElement(children: .combine)
  }
}

/// Hours that scroll sideways, six at a time.
private struct HourRow: View {
  let columns: [Column]

  var body: some View {
    // A hidden column sets the height; the hours scroll over it.
    ColumnView(column: Column(id: .distantPast, label: "0", symbol: "sun.max.fill", value: "0"))
      .hidden()
      .overlay {
        ScrollView(.horizontal) {
          LazyHStack(spacing: 0) {
            ForEach(columns) { column in
              ColumnView(column: column)
                .containerRelativeFrame(.horizontal, count: 6, spacing: 0)
            }
          }
          .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.viewAligned)
        .id(columns.first?.id)
      }
  }
}
