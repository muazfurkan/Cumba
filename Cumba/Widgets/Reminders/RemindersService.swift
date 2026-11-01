import EventKit
import Foundation

/// A reminder for display, safe to pass between threads.
struct ReminderItem: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let due: Date?
  /// Whether the due date has a time; a date alone means sometime that day.
  let dueHasTime: Bool

  func isOverdue(now: Date = .now) -> Bool {
    guard let due else { return false }
    return dueHasTime ? due < now : due < Calendar.current.startOfDay(for: now)
  }
}

/// A list in Apple Reminders.
struct ReminderList: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let color: HexColor?
}

/// Apple Reminders through EventKit. Being an actor keeps every EventKit call off the main
/// thread. Changes come back as `EKEventStoreChanged` notifications, never by polling.
actor RemindersService {
  private let store = EKEventStore()

  nonisolated static var hasAccess: Bool {
    EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
  }

  nonisolated static var accessWasDenied: Bool {
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .denied, .restricted, .writeOnly: true
    default: false
    }
  }

  /// Shows the system prompt. Call it from Settings or after closing the panel, so the
  /// prompt can't end up behind the panel.
  func requestAccess() async -> Bool {
    do {
      return try await store.requestFullAccessToReminders()
    } catch {
      Log.widgets.error(
        "Reminders access request failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  func lists() -> [ReminderList] {
    guard Self.hasAccess else { return [] }
    return store.calendars(for: .reminder)
      .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
      .map {
        ReminderList(
          id: $0.calendarIdentifier, title: $0.title, color: HexColor(cgColor: $0.cgColor))
      }
  }

  /// The chosen list, or the list new reminders go to by default.
  func list(_ id: String?) -> ReminderList? {
    guard Self.hasAccess else { return nil }
    let calendar =
      id.flatMap(store.calendar(withIdentifier:))
      ?? store.defaultCalendarForNewReminders()
    return calendar.map {
      ReminderList(
        id: $0.calendarIdentifier, title: $0.title, color: HexColor(cgColor: $0.cgColor))
    }
  }

  /// Reminders of a list that aren't done yet: due ones first by date, then the rest in the
  /// order they were made.
  func openReminders(in listID: String) async -> [ReminderItem] {
    guard Self.hasAccess, let calendar = store.calendar(withIdentifier: listID) else { return [] }
    let predicate = store.predicateForIncompleteReminders(
      withDueDateStarting: nil, ending: nil, calendars: [calendar])
    let items = await withCheckedContinuation { continuation in
      store.fetchReminders(matching: predicate) { reminders in
        let items = (reminders ?? []).map { reminder in
          let components = reminder.dueDateComponents
          return (
            item: ReminderItem(
              id: reminder.calendarItemIdentifier, title: reminder.title ?? "",
              due: components.flatMap { Calendar.current.date(from: $0) },
              dueHasTime: components?.hour != nil),
            created: reminder.creationDate ?? .distantPast
          )
        }
        continuation.resume(returning: items)
      }
    }
    return
      items
      .sorted { lhs, rhs in
        switch (lhs.item.due, rhs.item.due) {
        case (let left?, let right?): left < right
        case (.some, nil): true
        case (nil, .some): false
        case (nil, nil): lhs.created < rhs.created
        }
      }
      .map(\.item)
  }

  func complete(_ id: String) throws {
    guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
    reminder.isCompleted = true
    try store.save(reminder, commit: true)
  }

  func add(_ title: String, to listID: String) throws {
    guard let calendar = store.calendar(withIdentifier: listID) else { return }
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    reminder.calendar = calendar
    try store.save(reminder, commit: true)
  }
}
