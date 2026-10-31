import AppKit
import EventKit
import Observation
import SwiftUI

/// Today's and tomorrow's events. Reads EventKit only while the widget is on screen and
/// reloads when the calendar database changes. With a meeting reminder turned on it also
/// keeps the next event in mind while the panel is closed: one task sleeps until the
/// reminder is due and a live activity counts down to the start.
@MainActor
@Observable
final class CalendarWidget: NotchWidget {
  static let kind = "calendar"
  static var title: String { String(localized: "Calendar", comment: "Widget name") }
  static let symbol = "calendar"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "Today's and tomorrow's events", comment: "Widget description")
  }
  static let addedByDefault = true

  /// Reminder choices in minutes before a meeting; 0 is off.
  static let reminderChoices = [0, 5, 10, 15]

  private(set) var events: [CalendarEvent] = []
  private(set) var hasAccess = CalendarService.hasAccess
  /// Minutes before an event's start to show a countdown; 0 turns it off.
  var reminderMinutes: Int {
    didSet {
      UserDefaults.standard.set(reminderMinutes, forKey: Self.reminderKey)
      updateReminderWatching()
    }
  }

  @ObservationIgnored let service = CalendarService()
  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private let panel: PanelControl
  @ObservationIgnored private var changeObserver: NSObjectProtocol?
  @ObservationIgnored private var reminderObserver: NSObjectProtocol?
  @ObservationIgnored private var reminderTask: Task<Void, Never>?

  private static let reminderKey = "calendar.reminderMinutes"
  private static let reminderActivityID = "calendar.reminder"

  required init(context: WidgetContext) {
    liveActivities = context.liveActivities
    panel = context.panel
    reminderMinutes = UserDefaults.standard.integer(forKey: Self.reminderKey)
    updateReminderWatching()
  }

  /// Removed from the panel: stops watching but keeps the reminder setting.
  func shutdown() {
    deactivate()
    stopReminder()
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
      scheduleReminder()
    }
  }

  // MARK: - Meeting reminder

  /// Watches the calendar while a reminder is set, even when the widget is off screen.
  private func updateReminderWatching() {
    if reminderMinutes > 0 {
      if reminderObserver == nil {
        reminderObserver = NotificationCenter.default.addObserver(
          forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.reload() }
        }
      }
      reload()
    } else {
      stopReminder()
    }
  }

  private func stopReminder() {
    if let reminderObserver {
      NotificationCenter.default.removeObserver(reminderObserver)
    }
    reminderObserver = nil
    reminderTask?.cancel()
    reminderTask = nil
    liveActivities.dismiss(Self.reminderActivityID)
  }

  /// Sleeps until the next timed event's reminder, shows the countdown until it starts,
  /// then reloads, which schedules the one after.
  private func scheduleReminder() {
    reminderTask?.cancel()
    guard reminderMinutes > 0,
      let next = events.first(where: { !$0.isAllDay && $0.start > .now })
    else { return }
    let lead = TimeInterval(reminderMinutes * 60)
    reminderTask = Task { [weak self] in
      do {
        let wait = next.start.addingTimeInterval(-lead).timeIntervalSinceNow
        if wait > 0 {
          try await Task.sleep(for: .seconds(wait))
        }
        self?.showReminder(for: next)
        try await Task.sleep(for: .seconds(max(0, next.start.timeIntervalSinceNow)))
      } catch {
        return
      }
      self?.liveActivities.dismiss(Self.reminderActivityID)
      self?.reload()
    }
  }

  private func showReminder(for event: CalendarEvent) {
    liveActivities.show(
      LiveActivity(
        id: Self.reminderActivityID, priority: .calendar,
        leading: AnyView(
          Image(systemName: event.meetingURL == nil ? "calendar" : "video.fill")
            .foregroundStyle(event.color?.color ?? .accentColor)),
        trailing: AnyView(
          Text(timerInterval: Date()...event.start, countsDown: true)
            .font(.caption.monospacedDigit())
            .multilineTextAlignment(.trailing))))
  }

  /// Shows the system prompt. Call it from a normal window, or through
  /// `requestAccessFromPanel()`.
  func requestAccess() async {
    NSApp.activate()
    _ = await service.requestAccess()
    reload()
  }

  /// Closes the panel first, so the prompt can't end up behind it.
  func requestAccessFromPanel() {
    panel.close()
    Task { await requestAccess() }
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
          if CalendarService.accessWasDenied {
            Text("Calendar access is off. You can allow it in System Settings.")
              .font(.caption)
              .fixedSize(horizontal: false, vertical: true)
            OpenPrivacySettings(pane: "Privacy_Calendars")
              .controlSize(.small)
          } else {
            Text("See today's and tomorrow's events here.")
              .font(.caption)
              .fixedSize(horizontal: false, vertical: true)
            Button("Allow Calendar Access") { widget.requestAccessFromPanel() }
              .controlSize(.small)
          }
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
      if canJoin, let url = event.meetingURL {
        Spacer(minLength: 4)
        Button("Join") { NSWorkspace.shared.open(url) }
          .controlSize(.mini)
          .buttonStyle(.borderedProminent)
          .help(Text(url.host() ?? ""))
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// Join appears from 15 minutes before the start until the end.
  private var canJoin: Bool {
    event.meetingURL != nil && event.start.addingTimeInterval(-15 * 60) <= .now && event.end > .now
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
  @Bindable var widget: CalendarWidget

  var body: some View {
    if widget.hasAccess {
      Label("Calendar access granted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
      Picker("Meeting reminder", selection: $widget.reminderMinutes) {
        ForEach(CalendarWidget.reminderChoices, id: \.self) { minutes in
          if minutes == 0 {
            Text("Off").tag(minutes)
          } else {
            Text("\(minutes) min before", comment: "Meeting reminder time").tag(minutes)
          }
        }
      }
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
