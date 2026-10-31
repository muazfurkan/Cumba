import AppKit

/// Reports when the pointer enters or leaves a screen rect. Uses mouse event monitors
/// instead of polling; monitoring mouse (not keyboard) events needs no permission.
@MainActor
final class HoverTracker {
  /// Area to watch, in screen coordinates.
  var rect = CGRect.null {
    didSet { update() }
  }
  var onChange: ((Bool) -> Void)?
  /// Called for every pointer move that stays inside.
  var onMoveInside: (() -> Void)?
  private(set) var isInside = false
  private var monitors: [Any] = []

  func start() {
    guard monitors.isEmpty else { return }
    let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
    // Global monitors see events sent to other apps, local ones events sent to this app.
    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: events,
      handler: { [weak self] _ in
        MainActor.assumeIsolated { self?.pointerMoved() }
      })
    {
      monitors.append(monitor)
    }
    if let monitor = NSEvent.addLocalMonitorForEvents(
      matching: events,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.pointerMoved() }
        return event
      })
    {
      monitors.append(monitor)
    }
    update()
  }

  func stop() {
    for monitor in monitors {
      NSEvent.removeMonitor(monitor)
    }
    monitors.removeAll()
    setInside(false)
  }

  func update() {
    setInside(!monitors.isEmpty && rect.contains(NSEvent.mouseLocation))
  }

  private func pointerMoved() {
    let wasInside = isInside
    update()
    if wasInside && isInside {
      onMoveInside?()
    }
  }

  private func setInside(_ inside: Bool) {
    guard inside != isInside else { return }
    isInside = inside
    onChange?(inside)
  }
}
