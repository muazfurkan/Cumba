import AppKit
import SwiftUI

/// Follows a horizontal two-finger swipe on the trackpad, so the tab pages can move with the
/// fingers. Mostly vertical scrolling never counts, and momentum after the fingers lift is
/// ignored.
struct TabSwipeTracker {
  enum Update: Equatable {
    /// The fingers have moved this far sideways since the gesture began.
    case drag(CGFloat)
    /// The fingers lifted after moving this far.
    case end(CGFloat)
  }

  /// How far the fingers travel, in points, before letting go moves to the next tab.
  static let threshold: CGFloat = 50
  /// Movement before deciding whether the gesture is sideways or vertical.
  static let slop: CGFloat = 6

  private var travel = CGSize.zero
  private var isDragging = false
  private var isVertical = false

  /// - Parameter fingerDelta: How the fingers moved, positive to the right and down.
  mutating func update(phase: NSEvent.Phase, fingerDelta: CGSize) -> Update? {
    if phase.contains(.began) || phase.contains(.mayBegin) {
      reset()
    }
    if phase.contains(.ended) || phase.contains(.cancelled) {
      defer { reset() }
      return isDragging ? .end(travel.width) : nil
    }
    guard phase.contains(.began) || phase.contains(.changed), !isVertical else { return nil }
    travel.width += fingerDelta.width
    travel.height += fingerDelta.height
    if !isDragging {
      guard max(abs(travel.width), abs(travel.height)) >= Self.slop else { return nil }
      guard abs(travel.width) > abs(travel.height) * 1.5 else {
        isVertical = true
        return nil
      }
      isDragging = true
    }
    return .drag(travel.width)
  }

  /// Where letting go leads: +1 for the next tab when the fingers moved left, -1 for the
  /// previous one, nil to stay.
  static func step(forTravel travel: CGFloat) -> Int? {
    guard abs(travel) >= threshold else { return nil }
    return travel < 0 ? 1 : -1
  }

  private mutating func reset() {
    travel = .zero
    isDragging = false
    isVertical = false
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
  var onDrag: ((CGFloat) -> Void)?
  var onEnd: ((CGFloat) -> Void)?

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
    switch tracker.update(phase: phase, fingerDelta: delta) {
    case .drag(let travel): onDrag?(travel)
    case .end(let travel): onEnd?(travel)
    case nil: break
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

/// A page on its way off to the left (-1) or right (+1).
struct LeavingPage: Equatable {
  let tabID: String
  let side: CGFloat
}

extension WidgetHost {
  static let pageAnimation = Animation.spring(response: 0.38, dampingFraction: 0.86)

  /// Opens a tab with the pages sliding toward it, the open one leaving to the other side.
  func slide(to tabID: String) {
    guard let from = selectedTab, from.id != tabID else { return }
    withAnimation(Self.pageAnimation) {
      pageDrag = 0
      select(tabID)
      leavingPage = LeavingPage(tabID: from.id, side: -CGFloat(pageDirection))
    } completion: { [weak self] in
      self?.pageLeft(from.id)
    }
  }

  private func pageLeft(_ tabID: String) {
    if leavingPage?.tabID == tabID {
      leavingPage = nil
    }
  }

  /// Moves the pages with the fingers. Past the first or last tab they only give a little.
  func dragPages(to travel: CGFloat) {
    let hadNeighbor = swipeNeighbor?.id
    pageDrag = travel
    if swipeNeighbor == nil {
      pageDrag = travel * 0.25
    }
    if swipeNeighbor?.id != hadNeighbor {
      updateActivation()
    }
  }

  /// Lets go of the pages: far enough moves to the tab they were dragged toward, otherwise
  /// they settle back and the neighbor slides away again. Returns whether the tab changed.
  @discardableResult
  func endPageDrag(travel: CGFloat) -> Bool {
    guard let neighbor = swipeNeighbor else {
      withAnimation(Self.pageAnimation) { pageDrag = 0 }
      return false
    }
    if TabSwipeTracker.step(forTravel: travel) != nil {
      slide(to: neighbor.id)
      return true
    }
    let side: CGFloat = pageDrag < 0 ? 1 : -1
    withAnimation(Self.pageAnimation) {
      pageDrag = 0
      leavingPage = LeavingPage(tabID: neighbor.id, side: side)
    } completion: { [weak self] in
      self?.pageLeft(neighbor.id)
    }
    updateActivation()
    return false
  }

  /// Opens the tab before (-1) or after (+1) the open one, as clicking it would. Returns
  /// false at either end.
  @discardableResult
  func selectTab(offset: Int) -> Bool {
    guard let index = tabs.firstIndex(where: { $0.id == selectedTab?.id }),
      tabs.indices.contains(index + offset)
    else { return false }
    slide(to: tabs[index + offset].id)
    return true
  }
}
