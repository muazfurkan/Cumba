import AppKit

/// Owns the notch panel: places it on the notched screen and connects it to the view model.
@MainActor
final class NotchWindowController {
  private let settings: AppSettings
  private let model = NotchViewModel()
  private let hoverTracker = HoverTracker()
  private var panel: NotchPanel?
  private var observers: [NSObjectProtocol] = []
  private var fullScreenTask: Task<Void, Never>?
  /// A full screen app covers the notched screen, so the panel stays hidden (SPEC § 6).
  private var isFullScreenActive = false

  init(settings: AppSettings) {
    self.settings = settings
  }

  func start() {
    hoverTracker.onChange = { [weak self] inside in
      self?.pointerInsideChanged(inside)
    }
    hoverTracker.onMoveInside = { [weak self] in
      self?.model.send(.pointerMoved)
    }
    model.onStateChange = { [weak self] _ in
      self?.updateHoverArea()
    }
    observeSystemEvents()
    layoutPanel()
    refreshFullScreenState()
  }

  /// Re-places the panel whenever the screen setup, sleep state, space or pause
  /// setting changes (SPEC § 6, N3).
  private func observeSystemEvents() {
    let relayout: @Sendable (Notification) -> Void = { [weak self] _ in
      MainActor.assumeIsolated { self?.layoutPanel() }
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil,
        queue: .main, using: relayout))
    let workspace = NSWorkspace.shared.notificationCenter
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: relayout))
    // Entering or leaving a full screen app switches spaces.
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.layoutPanel()
          self?.refreshFullScreenState()
        }
      })
    observePause()
  }

  /// Re-registers after every change, as `withObservationTracking` fires only once.
  /// (`Observations` would be simpler but crashes the Swift 6.2 compiler in CI.)
  private func observePause() {
    withObservationTracking {
      _ = settings.isPaused
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.layoutPanel()
        self?.observePause()
      }
    }
  }

  /// Reads the window list off the main thread: once right away and once more after the
  /// space switch animation, when a new full screen window has settled.
  private func refreshFullScreenState() {
    fullScreenTask?.cancel()
    fullScreenTask = Task { [weak self] in
      for delay in [Duration.zero, .milliseconds(700)] {
        do {
          try await Task.sleep(for: delay)
        } catch {
          return
        }
        guard let screen = NSScreen.notched, let geometry = screen.notchGeometry() else {
          self?.setFullScreenActive(false)
          continue
        }
        let frame = screen.cgFrame
        let notchHeight = geometry.notchRect.height
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let isFullScreen = await Task.detached {
          FullScreenDetector.isFullScreen(
            windows: FullScreenDetector.currentWindows(excluding: ownPID),
            screen: frame,
            notchHeight: notchHeight)
        }.value
        guard !Task.isCancelled else { return }
        self?.setFullScreenActive(isFullScreen)
      }
    }
  }

  private func setFullScreenActive(_ active: Bool) {
    guard active != isFullScreenActive else { return }
    isFullScreenActive = active
    Log.notch.info("Full screen app on the notched screen: \(active, privacy: .public)")
    layoutPanel()
  }

  /// Puts the panel under the notch, or hides it when paused, behind a full screen app or
  /// when no screen has a notch.
  func layoutPanel() {
    guard !settings.isPaused, !isFullScreenActive, let geometry = NSScreen.notched?.notchGeometry()
    else {
      hidePanel()
      return
    }
    model.geometry = geometry
    let panel = panel ?? makePanel()
    self.panel = panel
    panel.setFrame(geometry.windowFrame, display: true)
    panel.orderFrontRegardless()
    hoverTracker.start()
    updateHoverArea()
    Log.notch.info("Panel placed at \(String(describing: geometry.windowFrame), privacy: .public)")
  }

  private func hidePanel() {
    hoverTracker.stop()
    model.send(.reset)
    panel?.ignoresMouseEvents = true
    panel?.orderOut(nil)
  }

  /// The panel takes mouse events only while the pointer is over its shape; everywhere
  /// else clicks go through to the menu bar.
  private func pointerInsideChanged(_ inside: Bool) {
    panel?.ignoresMouseEvents = !inside
    model.send(inside ? .pointerEntered : .pointerExited)
  }

  private func updateHoverArea() {
    hoverTracker.rect = model.geometry?.hoverRect(for: model.state) ?? .null
  }

  private func makePanel() -> NotchPanel {
    let panel = NotchPanel(showsInFullScreen: false)
    let hostingView = NotchHostingView(rootView: NotchRootView(model: model))
    // The window size is fixed; SwiftUI must not resize it.
    hostingView.sizingOptions = []
    panel.contentView = hostingView
    return panel
  }
}
