import Observation
import SwiftUI

/// Small indicator shown on both sides of the closed notch.
struct LiveActivity: Identifiable {
  /// Higher wins when several activities are active at once.
  enum Priority: Int, Comparable, Sendable {
    case media
    case keepAwake
    case timerRunning
    case battery
    case script
    case calendar
    case claudeStatus
    case privacy
    case timerFinished
    /// A volume change, shown briefly right after a key press.
    case volume
    case claudePermission

    static func < (lhs: Priority, rhs: Priority) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  let id: String
  let priority: Priority
  /// Shown left of the notch, usually an icon.
  let leading: AnyView
  /// Shown right of the notch, usually a short text.
  let trailing: AnyView
  var startedAt = Date()
}

/// Collects live activities from widgets and services and picks the one to show.
@MainActor
@Observable
final class LiveActivityCenter {
  private(set) var activities: [String: LiveActivity] = [:]
  @ObservationIgnored private var expirations: [String: Task<Void, Never>] = [:]

  /// Highest priority wins; among equals the most recent one.
  var current: LiveActivity? {
    activities.values.max { lhs, rhs in
      (lhs.priority, lhs.startedAt) < (rhs.priority, rhs.startedAt)
    }
  }

  /// Shows or replaces an activity. With a duration it disappears on its own.
  func show(_ activity: LiveActivity, for duration: Duration? = nil) {
    activities[activity.id] = activity
    expirations[activity.id]?.cancel()
    expirations[activity.id] = nil
    guard let duration else { return }
    expirations[activity.id] = Task { [weak self] in
      do {
        try await Task.sleep(for: duration)
      } catch {
        return
      }
      self?.dismiss(activity.id)
    }
  }

  func dismiss(_ id: String) {
    expirations[id]?.cancel()
    expirations[id] = nil
    activities[id] = nil
  }

  func contains(_ id: String) -> Bool {
    activities[id] != nil
  }
}
