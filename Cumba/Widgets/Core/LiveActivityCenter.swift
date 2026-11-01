import Observation
import SwiftUI

/// Small indicator shown on both sides of the closed notch.
struct LiveActivity: Identifiable {
  /// Higher wins when several activities are active at once.
  enum Priority: Int, Comparable, Sendable {
    case media
    /// Stays while the battery is low, above music but below anything that comes and goes.
    case lowBattery
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
  /// Width of each side when it needs more room than the theme gives, e.g. for a title.
  var sideWidth: CGFloat? = nil
  /// Opens under the notch for a while, then folds into `leading` and `trailing`.
  var notification: LiveNotification? = nil

  /// Side width that fits a short label in the peek's caption font, so it isn't cut off;
  /// at most 180 points.
  @MainActor
  static func sideWidth(for label: String) -> CGFloat {
    let size = NSFont.preferredFont(forTextStyle: .caption1).pointSize
    let font = NSFont.systemFont(ofSize: size, weight: .semibold)
    let width = (label as NSString).size(withAttributes: [.font: font]).width
    return min(ceil(width) + 20, 180)
  }
  var startedAt = Date()
}

/// Collects live activities from widgets and services and picks the one to show.
@MainActor
@Observable
final class LiveActivityCenter {
  private(set) var activities: [String: LiveActivity] = [:]
  @ObservationIgnored private var timers: [String: Task<Void, Never>] = [:]
  /// While the pointer rests on the notch, an open notification stays open.
  @ObservationIgnored var isPointerOver = false

  /// Highest priority wins; among equals the most recent one.
  var current: LiveActivity? {
    activities.values.max { lhs, rhs in
      (lhs.priority, lhs.startedAt) < (rhs.priority, rhs.startedAt)
    }
  }

  /// Shows or replaces an activity. Its notification folds after its own duration; with a
  /// duration the activity then disappears that much later.
  func show(_ activity: LiveActivity, for duration: Duration? = nil) {
    activities[activity.id] = activity
    timers[activity.id]?.cancel()
    timers[activity.id] = nil
    let fold = activity.notification?.duration
    guard fold != nil || duration != nil else { return }
    timers[activity.id] = Task { [weak self] in
      do {
        if let fold {
          try await Task.sleep(for: fold)
          // Checked once a second, and only while the pointer is on the open notification.
          while self?.isPointerOver == true {
            try await Task.sleep(for: .seconds(1))
          }
          self?.activities[activity.id]?.notification = nil
        }
        if let duration {
          try await Task.sleep(for: duration)
          self?.dismiss(activity.id)
        }
      } catch {
        return
      }
    }
  }

  func dismiss(_ id: String) {
    timers[id]?.cancel()
    timers[id] = nil
    activities[id] = nil
  }

  func contains(_ id: String) -> Bool {
    activities[id] != nil
  }
}
