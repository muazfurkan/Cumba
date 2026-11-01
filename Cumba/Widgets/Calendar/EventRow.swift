import AppKit
import SwiftUI

/// One event: its calendar's color, title and time, and Join for a call about to start.
/// Resting the pointer on it shows its location and notes; events that are over are dimmed.
struct EventRow: View {
  let event: CalendarEvent

  var body: some View {
    HStack(spacing: 6) {
      Capsule()
        .fill(event.color?.color ?? .accentColor)
        .frame(width: 3, height: 26)
      VStack(alignment: .leading, spacing: 0) {
        Text(event.title)
          .panelFont(.caption, weight: .medium)
          .lineLimit(1)
        Text(timeText)
          .panelFont(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if canJoin, let url = event.meetingURL {
        Spacer(minLength: 4)
        Button("Join") { NSWorkspace.shared.open(url) }
          .controlSize(.mini)
          .buttonStyle(.borderedProminent)
          .help(Text(url.host() ?? ""))
      }
    }
    .opacity(event.end <= .now ? 0.5 : 1)
    .contentShape(Rectangle())
    .help(Text(verbatim: details))
    .accessibilityElement(children: .combine)
  }

  /// Location and notes, empty when the event has neither.
  private var details: String {
    [event.location, event.notes].compactMap(\.self).joined(separator: "\n\n")
  }

  /// Join appears from 15 minutes before the start until the end.
  private var canJoin: Bool {
    event.meetingURL != nil && event.start.addingTimeInterval(-15 * 60) <= .now && event.end > .now
  }

  private var timeText: String {
    let calendar = Calendar.current
    let day =
      if calendar.isDateInToday(event.start) {
        String(localized: "Today")
      } else if calendar.isDateInTomorrow(event.start) {
        String(localized: "Tomorrow")
      } else if calendar.isDateInYesterday(event.start) {
        String(localized: "Yesterday")
      } else {
        event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
      }
    if event.isAllDay {
      return String(localized: "\(day), all day", comment: "Calendar event time")
    }
    let time = event.start.formatted(date: .omitted, time: .shortened)
    return String(localized: "\(day), \(time)", comment: "Calendar event day and time")
  }
}
