import SwiftUI

/// A day at a glance, like the macOS Calendar widget: the month, a strip of days and the
/// day's events. Scrolling the days or clicking one shows that day; today shows what's
/// coming today and tomorrow. Alone in its tab it shows whole months, one under another.
struct CalendarAgenda: View {
  /// The picked day; nil is today.
  let day: Date?
  let events: [CalendarEvent]
  let select: (Date) -> Void
  @Environment(\.showsDetailedWidget) private var isDetailed

  private var shownDay: Date { day ?? Calendar.current.startOfDay(for: .now) }

  var body: some View {
    if isDetailed {
      HStack(alignment: .top, spacing: 16) {
        MonthPager(selected: shownDay, select: select)
          .frame(width: 176)
        Rectangle()
          .fill(.white.opacity(0.12))
          .frame(width: 1)
        VStack(alignment: .leading, spacing: 6) {
          if day != nil {
            header
          }
          EventList(events: events, limit: day == nil ? 4 : 3, isToday: day == nil)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .center, spacing: 6) {
          // Back to today from another day.
          Button {
            select(.now)
          } label: {
            Text(shownDay.formatted(.dateTime.month(.abbreviated)))
              .panelFont(size: 20, weight: .bold)
              .lineLimit(1)
              .fixedSize()
          }
          .buttonStyle(.plain)
          .help(day == nil ? Text(verbatim: "") : Text("Today"))
          DayStrip(selected: shownDay, select: select)
        }
        EventList(events: events, limit: 2, isToday: day == nil)
      }
    }
  }

  /// The picked day and a way back to today.
  private var header: some View {
    HStack {
      Text(shownDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .panelFont(.caption, weight: .semibold)
        .lineLimit(1)
      Spacer(minLength: 4)
      Button("Today") { select(.now) }
        .buttonStyle(.plain)
        .panelFont(.caption, weight: .medium)
        .foregroundStyle(.tint)
    }
  }
}

/// Days in a row that scroll sideways, five at a time. The day in the middle is the one
/// shown; clicking a day brings it to the middle. The edges fade out.
private struct DayStrip: View {
  let selected: Date
  let select: (Date) -> Void
  @State private var centered: Int?

  /// Days around today the strip reaches; symmetric, so centering the content shows today.
  private static let reach = 120

  private var calendar: Calendar { .current }
  private var today: Date { calendar.startOfDay(for: .now) }

  private var selectedOffset: Int {
    calendar.dateComponents([.day], from: today, to: selected).day ?? 0
  }

  var body: some View {
    // A hidden day sets the height, so the strip never shrinks to make room for events.
    cell(0)
      .hidden()
      .overlay {
        ScrollView(.horizontal) {
          LazyHStack(spacing: 0) {
            ForEach(-Self.reach...Self.reach, id: \.self) { offset in
              cell(offset)
                .containerRelativeFrame(.horizontal, count: 5, spacing: 0)
            }
          }
          .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centered, anchor: .center)
        .defaultScrollAnchor(.center)
      }
      .onAppear { centered = selectedOffset }
      .onChange(of: centered) { _, offset in
        guard let offset, offset != selectedOffset,
          let day = calendar.date(byAdding: .day, value: offset, to: today)
        else { return }
        select(day)
      }
      .onChange(of: selectedOffset) { _, offset in
        guard centered != offset else { return }
        withAnimation(.smooth(duration: 0.3)) { centered = offset }
      }
  }

  @ViewBuilder private func cell(_ offset: Int) -> some View {
    if let day = calendar.date(byAdding: .day, value: offset, to: today) {
      let isToday = offset == 0
      let isSelected = offset == selectedOffset
      VStack(spacing: 1) {
        Text(day.formatted(.dateTime.weekday(.narrow)).uppercased())
          .panelFont(.caption2, weight: .semibold)
          .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        Text(day.formatted(.dateTime.day()))
          .panelFont(
            .callout, weight: isToday || isSelected ? .bold : .medium, monospacedDigit: true
          )
          .minimumScaleFactor(0.6)
          .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
      }
      .lineLimit(1)
      .padding(.vertical, 2)
      .frame(maxWidth: .infinity)
      .background {
        if isSelected && !isToday {
          RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.14))
        }
      }
      .opacity(Self.fade(abs(offset - (centered ?? selectedOffset))))
      .contentShape(Rectangle())
      .onTapGesture {
        withAnimation(.smooth(duration: 0.3)) { centered = offset }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
  }

  private static func fade(_ distance: Int) -> Double {
    [1, 0.8, 0.45][safe: distance] ?? 0.3
  }
}

/// Months one under another below a fixed title and weekday row; scrolling up or down
/// pages through them. Clicking a day shows its events.
private struct MonthPager: View {
  let selected: Date
  let select: (Date) -> Void
  @State private var shownMonth: Int?

  private static let reach = 24
  private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

  private var calendar: Calendar { .current }
  private var thisMonth: Date { calendar.dateInterval(of: .month, for: .now)?.start ?? .now }

  private var selectedMonth: Int {
    calendar.dateComponents([.month], from: thisMonth, to: selected).month ?? 0
  }

  private func month(_ offset: Int) -> Date {
    calendar.date(byAdding: .month, value: offset, to: thisMonth) ?? thisMonth
  }

  var body: some View {
    let shown = month(shownMonth ?? selectedMonth)
    VStack(alignment: .leading, spacing: 2) {
      Text(shown.formatted(MonthDays.title(for: shown)).uppercased())
        .panelFont(.caption, weight: .bold)
        .foregroundStyle(.tint)
        .lineLimit(1)
        .contentTransition(.numericText())
      LazyVGrid(columns: Self.columns, spacing: 0) {
        ForEach(Array(MonthDays.weekdayLetters(calendar).enumerated()), id: \.offset) {
          _, letter in
          Text(letter)
            .panelFont(.caption2, weight: .semibold)
            .foregroundStyle(.secondary)
            .frame(height: MonthDays.rowHeight)
        }
      }
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(-Self.reach...Self.reach, id: \.self) { offset in
            MonthDays(month: month(offset), selected: selected, select: select)
              .containerRelativeFrame(.vertical, alignment: .top)
          }
        }
        .scrollTargetLayout()
      }
      .scrollIndicators(.never)
      .scrollTargetBehavior(.paging)
      .scrollPosition(id: $shownMonth)
      .defaultScrollAnchor(.center)
    }
    .animation(.smooth(duration: 0.2), value: shownMonth)
    .onAppear { shownMonth = selectedMonth }
    .onChange(of: selectedMonth) { _, month in
      guard shownMonth != month else { return }
      withAnimation(.smooth(duration: 0.3)) { shownMonth = month }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(shown.formatted(.dateTime.month(.wide).year())))
  }
}

/// One month's days in week rows: today filled in, the picked day ringed.
private struct MonthDays: View {
  let month: Date
  let selected: Date
  let select: (Date) -> Void

  /// Six weeks fit the widget at this height.
  static let rowHeight: CGFloat = 14

  var body: some View {
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    LazyVGrid(columns: columns, spacing: 0) {
      ForEach(Array(Self.cells(for: month, calendar: calendar).enumerated()), id: \.offset) {
        _, day in
        if let day {
          dayCell(day, calendar: calendar)
        } else {
          Color.clear.frame(height: Self.rowHeight)
        }
      }
    }
  }

  private func dayCell(_ day: Date, calendar: Calendar) -> some View {
    let isToday = calendar.isDateInToday(day)
    let isSelected = calendar.isDate(day, inSameDayAs: selected)
    return Text(day.formatted(.dateTime.day()))
      .panelFont(
        .caption2, weight: isToday || isSelected ? .bold : .regular, monospacedDigit: true
      )
      .minimumScaleFactor(0.7)
      .frame(width: 18, height: Self.rowHeight)
      .background(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: Capsule())
      .overlay {
        if isSelected && !isToday {
          Capsule().stroke(.white.opacity(0.6), lineWidth: 1)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture { select(day) }
      .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  /// The month's name, with the year when it isn't this year.
  static func title(for month: Date) -> Date.FormatStyle {
    Calendar.current.isDate(month, equalTo: .now, toGranularity: .year)
      ? .dateTime.month(.wide) : .dateTime.month(.wide).year()
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

/// The events to show, or a calm note when there are none.
private struct EventList: View {
  let events: [CalendarEvent]
  let limit: Int
  let isToday: Bool

  var body: some View {
    if events.isEmpty {
      VStack(spacing: 4) {
        Image(systemName: "calendar.badge.checkmark")
          .panelFont(.title3)
          .accessibilityHidden(true)
        Group {
          if isToday {
            Text("Nothing planned for today and tomorrow.")
          } else {
            Text("Nothing planned for this day.")
          }
        }
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
        if events.count > limit {
          Text("+\(events.count - limit) more", comment: "More calendar events than fit")
            .panelFont(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
