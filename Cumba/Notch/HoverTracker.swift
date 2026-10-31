import AppKit

/// Reports when the pointer enters or leaves a screen rect. Uses mouse event monitors
/// instead of polling; monitoring mouse (not keyboard) events needs no permission.
///
/// While a mouse button is held, the pointer only counts as entering when files are being
/// dragged (to drop them on the tray), so dragging a window or a browser tab past the
/// notch doesn't open the panel.
@MainActor
final class HoverTracker {
  /// Area to watch, in screen coordinates.
  var rect = CGRect.null {
    didSet { update() }
  }
  var onChange: ((Bool) -> Void)?
  /// Called for every pointer move that stays inside.
  var onMoveInside: (() -> Void)?
  /// Called for every pointer move, inside or not.
  var onMove: (() -> Void)?
  private(set) var isInside = false
  private var monitors: [Any] = []
  /// Drag pasteboard change count at the last mouse down; a new drag writes to it.
  private var dragChangeCountAtMouseDown = 0

  func start() {
    guard monitors.isEmpty else { return }
    let events: NSEvent.EventTypeMask = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown,
    ]
    // Global monitors see events sent to other apps, local ones events sent to this app.
    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: events,
      handler: { [weak self] event in
        let type = event.type
        MainActor.assumeIsolated { self?.handle(type) }
      })
    {
      monitors.append(monitor)
    }
    if let monitor = NSEvent.addLocalMonitorForEvents(
      matching: events,
      handler: { [weak self] event in
        let type = event.type
        MainActor.assumeIsolated { self?.handle(type) }
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

  private func handle(_ type: NSEvent.EventType) {
    if type != .leftMouseDown {
      onMove?()
    }
    switch type {
    case .leftMouseDown:
      dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    case .leftMouseDragged, .rightMouseDragged:
      let wasInside = isInside
      let inside = !monitors.isEmpty && rect.contains(NSEvent.mouseLocation)
      // Entering during a drag counts only for files; leaving always counts.
      setInside(inside && (wasInside || isDraggingFiles))
      if wasInside && isInside {
        onMoveInside?()
      }
    default:
      let wasInside = isInside
      update()
      if wasInside && isInside {
        onMoveInside?()
      }
    }
  }

  /// True when the current drag started after the last mouse down and carries file URLs.
  private var isDraggingFiles: Bool {
    let pasteboard = NSPasteboard(name: .drag)
    return pasteboard.changeCount != dragChangeCountAtMouseDown
      && pasteboard.types?.contains(.fileURL) == true
  }

  private func setInside(_ inside: Bool) {
    guard inside != isInside else { return }
    isInside = inside
    onChange?(inside)
  }
}
