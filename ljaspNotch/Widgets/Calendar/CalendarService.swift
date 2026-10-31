import EventKit
import Foundation

/// Event for display, safe to pass between threads.
struct CalendarEvent: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let start: Date
  let end: Date
  let isAllDay: Bool
  let color: HexColor?
}

/// Owns the EventKit store. Being an actor keeps every EventKit call off the main thread.
actor CalendarService {
  private let store = EKEventStore()

  nonisolated static var hasAccess: Bool {
    EKEventStore.authorizationStatus(for: .event) == .fullAccess
  }

  nonisolated static var accessWasDenied: Bool {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .denied, .restricted, .writeOnly: true
    default: false
    }
  }

  /// Shows the system prompt. Call it from the Settings window, never from the panel, so
  /// the prompt can't end up behind the panel.
  func requestAccess() async -> Bool {
    do {
      return try await store.requestFullAccessToEvents()
    } catch {
      Log.widgets.error(
        "Calendar access request failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  /// Events from the start of today to the end of tomorrow that haven't ended yet.
  func upcomingEvents(now: Date = .now) -> [CalendarEvent] {
    guard Self.hasAccess else { return [] }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: now)
    guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return [] }
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    return store.events(matching: predicate)
      .filter { $0.endDate > now }
      .sorted { $0.startDate < $1.startDate }
      .map { event in
        CalendarEvent(
          id: event.eventIdentifier ?? UUID().uuidString,
          title: event.title ?? "",
          start: event.startDate,
          end: event.endDate,
          isAllDay: event.isAllDay,
          color: event.calendar.flatMap { HexColor(cgColor: $0.cgColor) })
      }
  }
}

extension HexColor {
  init?(cgColor: CGColor?) {
    guard let cgColor,
      let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
      let components = converted.components, components.count >= 3
    else { return nil }
    func byte(_ value: CGFloat) -> UInt8 {
      UInt8((min(max(value, 0), 1) * 255).rounded())
    }
    self.init(red: byte(components[0]), green: byte(components[1]), blue: byte(components[2]))
  }
}
