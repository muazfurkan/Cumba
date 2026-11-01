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
  /// Video call link found in the event's URL, location or notes.
  var meetingURL: URL?
  var location: String?
  /// The start of the event's notes, shown when the pointer rests on it.
  var notes: String?
}

/// Finds a video call link in an event for the Join button. Only https links to known
/// meeting services count, so a random link in the notes isn't offered.
enum MeetingLink {
  static let hosts = [
    "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
    "facetime.apple.com", "whereby.com", "meet.jit.si",
  ]

  static func find(url: URL?, texts: [String?]) -> URL? {
    if let url, isMeeting(url) {
      return url
    }
    guard
      let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return nil }
    for text in texts.compactMap(\.self) {
      let range = NSRange(text.startIndex..., in: text)
      for match in detector.matches(in: text, range: range) {
        if let url = match.url, isMeeting(url) {
          return url
        }
      }
    }
    return nil
  }

  static func isMeeting(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased() else {
      return false
    }
    return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
  }
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
    let start = Calendar.current.startOfDay(for: now)
    guard let end = Calendar.current.date(byAdding: .day, value: 2, to: start) else { return [] }
    return events(from: start, to: end).filter { $0.end > now }
  }

  /// Every event on one day, ended ones too, for looking at another day.
  func events(on day: Date) -> [CalendarEvent] {
    let start = Calendar.current.startOfDay(for: day)
    guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
    return events(from: start, to: end)
  }

  private func events(from start: Date, to end: Date) -> [CalendarEvent] {
    guard Self.hasAccess else { return [] }
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    return store.events(matching: predicate)
      .sorted { $0.startDate < $1.startDate }
      .map { event in
        CalendarEvent(
          id: event.eventIdentifier ?? UUID().uuidString,
          title: event.title ?? "",
          start: event.startDate,
          end: event.endDate,
          isAllDay: event.isAllDay,
          color: event.calendar.flatMap { HexColor(cgColor: $0.cgColor) },
          meetingURL: MeetingLink.find(url: event.url, texts: [event.location, event.notes]),
          location: Self.trimmed(event.location, to: 120),
          notes: Self.trimmed(event.notes, to: 300))
      }
  }

  private static func trimmed(_ text: String?, to length: Int) -> String? {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
    else { return nil }
    return text.count > length ? String(text.prefix(length - 1)) + "…" : text
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
