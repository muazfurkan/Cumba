import SwiftUI

/// Months one under another below a fixed title and weekday row; scrolling up or down
/// pages through them. Clicking a day shows its events.
struct MonthPager: View {
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
struct MonthDays: View {
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
