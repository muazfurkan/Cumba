import SwiftUI

/// Today at a glance, like the macOS Calendar widget: the month, a week strip with today
/// marked, and the next events. Alone in its tab it shows the whole month beside the list.
struct CalendarAgenda: View {
  let events: [CalendarEvent]
  @Environment(\.showsDetailedWidget) private var isDetailed

  var body: some View {
    if isDetailed {
      HStack(alignment: .top, spacing: 16) {
        MonthGrid(today: .now)
          .frame(width: 176)
        Rectangle()
          .fill(.white.opacity(0.12))
          .frame(width: 1)
        EventList(events: events, limit: 4)
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .center, spacing: 6) {
          Text(Date.now.formatted(.dateTime.month(.abbreviated)))
            .panelFont(size: 20, weight: .bold)
            .lineLimit(1)
            .fixedSize()
          WeekStrip(today: .now)
        }
        EventList(events: events, limit: 2)
      }
    }
  }
}

/// Two days on each side of today; today in the theme's accent, the edges fading out.
private struct WeekStrip: View {
  let today: Date

  var body: some View {
    let calendar = Calendar.current
    HStack(spacing: 0) {
      ForEach(-2...2, id: \.self) { offset in
        if let day = calendar.date(byAdding: .day, value: offset, to: today) {
          let isToday = offset == 0
          VStack(spacing: 1) {
            Text(day.formatted(.dateTime.weekday(.narrow)).uppercased())
              .panelFont(.caption2, weight: .semibold)
              .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(day.formatted(.dateTime.day()))
              .panelFont(.callout, weight: isToday ? .bold : .medium, monospacedDigit: true)
              .minimumScaleFactor(0.6)
              .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
          }
          .lineLimit(1)
          .frame(maxWidth: .infinity)
          .opacity([1, 0.8, 0.45][abs(offset)])
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(today.formatted(date: .complete, time: .omitted)))
  }
}

/// This month, weeks in rows, today circled.
private struct MonthGrid: View {
  let today: Date

  var body: some View {
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    VStack(alignment: .leading, spacing: 4) {
      Text(today.formatted(.dateTime.month(.wide)).uppercased())
        .panelFont(.caption, weight: .bold)
        .foregroundStyle(.tint)
      LazyVGrid(columns: columns, spacing: 2) {
        ForEach(Array(Self.weekdayLetters(calendar).enumerated()), id: \.offset) { _, letter in
          Text(letter)
            .panelFont(.caption2, weight: .semibold)
            .foregroundStyle(.secondary)
        }
        ForEach(Array(Self.cells(for: today, calendar: calendar).enumerated()), id: \.offset) {
          _, day in
          if let day {
            let isToday = calendar.isDate(day, inSameDayAs: today)
            Text(day.formatted(.dateTime.day()))
              .panelFont(.caption2, weight: isToday ? .bold : .regular, monospacedDigit: true)
              .frame(width: 18, height: 16)
              .background(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: Circle())
          } else {
            Color.clear.frame(height: 16)
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(today.formatted(.dateTime.month(.wide).year())))
  }

  /// Weekday initials in the order of the user's week.
  static func weekdayLetters(_ calendar: Calendar) -> [String] {
    let symbols = calendar.veryShortWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return Array(symbols[first...] + symbols[..<first])
  }

  /// The month's days with empty cells before the first, so weekdays line up.
  static func cells(for date: Date, calendar: Calendar) -> [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: date),
      let days = calendar.range(of: .day, in: .month, for: date)
    else { return [] }
    let weekday = calendar.component(.weekday, from: interval.start)
    let leading = (weekday - calendar.firstWeekday + 7) % 7
    let dates = days.compactMap { day in
      calendar.date(byAdding: .day, value: day - 1, to: interval.start)
    }
    return Array(repeating: nil, count: leading) + dates.map { Optional($0) }
  }
}

/// The next events, or a calm note when there are none.
private struct EventList: View {
  let events: [CalendarEvent]
  let limit: Int

  var body: some View {
    if events.isEmpty {
      VStack(spacing: 4) {
        Image(systemName: "calendar.badge.checkmark")
          .panelFont(.title3)
          .accessibilityHidden(true)
        Text("Nothing planned for today and tomorrow.")
          .panelFont(.callout)
          .multilineTextAlignment(.center)
      }
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(events.prefix(limit)) { event in
          EventRow(event: event)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
