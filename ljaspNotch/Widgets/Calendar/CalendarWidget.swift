import EventKit
import Observation
import SwiftUI

/// Today's and tomorrow's events. Reads EventKit only while the widget is on screen and
/// reloads when the calendar database changes.
@MainActor
@Observable
final class CalendarWidget: NotchWidget {
  static let kind = "calendar"
  static var title: String { String(localized: "Calendar", comment: "Widget name") }
  static let symbol = "calendar"

  private(set) var events: [CalendarEvent] = []
  private(set) var hasAccess = CalendarService.hasAccess
  let size = WidgetSize.regular

  @ObservationIgnored let service = CalendarService()
  @ObservationIgnored private let openSettings: @MainActor () -> Void
  @ObservationIgnored private var changeObserver: NSObjectProtocol?

  required init(context: WidgetContext) {
    openSettings = context.openSettings
  }

  func makeView() -> AnyView {
    AnyView(CalendarWidgetView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(CalendarAccessView(widget: self))
  }

  func activate() {
    reload()
    changeObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
  }

  func deactivate() {
    if let changeObserver {
      NotificationCenter.default.removeObserver(changeObserver)
    }
    changeObserver = nil
  }

  func reload() {
    hasAccess = CalendarService.hasAccess
    guard hasAccess else {
      events = []
      return
    }
    Task {
      events = await service.upcomingEvents()
    }
  }

  /// Asks for access; only called from the Settings window.
  func requestAccess() async {
    _ = await service.requestAccess()
    reload()
  }

  func showSettings() {
    openSettings()
  }
}

private struct CalendarWidgetView: View {
  let widget: CalendarWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        Label("Calendar", systemImage: "calendar")
          .font(.caption)
          .foregroundStyle(.secondary)
        if !widget.hasAccess {
          Text("Allow calendar access in Settings to see your events.")
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
          Button("Open Settings") { widget.showSettings() }
            .controlSize(.small)
        } else if widget.events.isEmpty {
          Text("Nothing planned for today and tomorrow.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(widget.events.prefix(3)) { event in
            EventRow(event: event)
          }
        }
      }
    }
  }
}

private struct EventRow: View {
  let event: CalendarEvent

  var body: some View {
    HStack(spacing: 6) {
      Capsule()
        .fill(event.color?.color ?? .accentColor)
        .frame(width: 3, height: 26)
      VStack(alignment: .leading, spacing: 0) {
        Text(event.title)
          .font(.caption.weight(.medium))
          .lineLimit(1)
        Text(timeText)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var timeText: String {
    let day =
      Calendar.current.isDateInToday(event.start)
      ? String(localized: "Today") : String(localized: "Tomorrow")
    if event.isAllDay {
      return String(localized: "\(day), all day", comment: "Calendar event time")
    }
    let time = event.start.formatted(date: .omitted, time: .shortened)
    return String(localized: "\(day), \(time)", comment: "Calendar event day and time")
  }
}

/// Shown in Settings: grants calendar access from a normal window.
private struct CalendarAccessView: View {
  let widget: CalendarWidget

  var body: some View {
    if widget.hasAccess {
      Label("Calendar access granted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    } else if CalendarService.accessWasDenied {
      VStack(alignment: .leading, spacing: 6) {
        Text("Calendar access was denied. You can allow it in System Settings.")
          .foregroundStyle(.secondary)
        Button("Open Privacy Settings") {
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
          {
            NSWorkspace.shared.open(url)
          }
        }
      }
    } else {
      Button("Allow Calendar Access") {
        Task { await widget.requestAccess() }
      }
    }
  }
}
