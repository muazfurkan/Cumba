import AppKit
import SwiftUI

/// Turns a horizontal two-finger swipe on the trackpad into one step between tabs. A
/// gesture moves at most one tab, momentum after the fingers lift is ignored, and mostly
/// vertical scrolling never counts.
struct TabSwipeTracker {
  /// How far the fingers travel, in points, before the tab changes.
  static let threshold: CGFloat = 40

  private var travel = CGSize.zero
  private var hasStepped = false

  /// - Parameter fingerDelta: How the fingers moved, positive to the right and down.
  /// - Returns: +1 for the next tab when the fingers move left, -1 for the previous one.
  mutating func update(phase: NSEvent.Phase, fingerDelta: CGSize) -> Int? {
    if phase.contains(.began) || phase.contains(.mayBegin) {
      travel = .zero
      hasStepped = false
    }
    if phase.contains(.ended) || phase.contains(.cancelled) {
      travel = .zero
      hasStepped = false
      return nil
    }
    guard phase.contains(.began) || phase.contains(.changed), !hasStepped else { return nil }
    travel.width += fingerDelta.width
    travel.height += fingerDelta.height
    guard abs(travel.width) >= Self.threshold, abs(travel.width) > abs(travel.height) * 1.5
    else { return nil }
    hasStepped = true
    return travel.width < 0 ? 1 : -1
  }
}

/// Watches scroll events sent to the panel for a tab swipe. A local event monitor sees them
/// before any scroll view in a widget does; the events still reach the widgets. A gesture
/// that starts over content that scrolls sideways, like the calendar's days, belongs to
/// that content.
@MainActor
final class TabSwipeMonitor {
  /// The panel's window; only its events count.
  var window: () -> NSWindow? = { nil }
  /// Whether a swipe may change the tab now.
  var isEnabled: () -> Bool = { false }
  var onStep: ((Int) -> Void)?

  private var monitor: Any?
  private var tracker = TabSwipeTracker()
  private var gestureBelongsToContent = false

  func start() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      // Only trackpad gestures have a phase; mouse wheels and momentum are left alone.
      if event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty, !event.phase.isEmpty {
        let phase = event.phase
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let delta = CGSize(
          width: event.scrollingDeltaX * sign, height: event.scrollingDeltaY * sign)
        let window = event.window
        let point = event.locationInWindow
        MainActor.assumeIsolated {
          self?.handle(phase: phase, delta: delta, at: point, in: window)
        }
      }
      return event
    }
  }

  private func handle(
    phase: NSEvent.Phase, delta: CGSize, at point: NSPoint, in eventWindow: NSWindow?
  ) {
    guard let eventWindow, eventWindow === window(), isEnabled() else { return }
    if phase.contains(.began) || phase.contains(.mayBegin) {
      gestureBelongsToContent = Self.scrollsSideways(at: point, in: eventWindow)
    }
    guard !gestureBelongsToContent else { return }
    if let step = tracker.update(phase: phase, fingerDelta: delta) {
      onStep?(step)
    }
  }
}

extension TabSwipeMonitor {
  /// Whether the view under the point sits in a scroll view that can scroll sideways.
  static func scrollsSideways(at point: NSPoint, in window: NSWindow) -> Bool {
    var view = window.contentView?.hitTest(point)
    while let current = view {
      if let scrollView = current as? NSScrollView, let document = scrollView.documentView,
        document.frame.width > scrollView.contentView.bounds.width + 1
      {
        return true
      }
      view = current.superview
    }
    return false
  }
}

extension WidgetHost {
  /// Opens the tab before (-1) or after (+1) the open one, as clicking it would. Returns
  /// false at either end.
  @discardableResult
  func selectTab(offset: Int) -> Bool {
    guard let index = tabs.firstIndex(where: { $0.id == selectedTab?.id }),
      tabs.indices.contains(index + offset)
    else { return false }
    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
      select(tabs[index + offset].id)
    }
    return true
  }
}
