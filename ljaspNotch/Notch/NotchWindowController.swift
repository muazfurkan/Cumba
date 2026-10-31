import AppKit

/// Owns the notch panel: places it on the right screen and connects it to the view model,
/// the settings and the current theme.
@MainActor
final class NotchWindowController {
  private let settings: AppSettings
  private let themes: ThemeStore
  private let host: WidgetHost
  private let model = NotchViewModel()
  private let hoverTracker = HoverTracker()
  private var panel: NotchPanel?
  private var observers: [NSObjectProtocol] = []
  private var fullScreenTask: Task<Void, Never>?
  /// A full screen app covers the panel's screen.
  private var isFullScreenActive = false
  private var isPreviewing = false
  private var lastState = NotchState.closed

  init(settings: AppSettings, themes: ThemeStore, host: WidgetHost) {
    self.settings = settings
    self.themes = themes
    self.host = host
  }

  func start() {
    hoverTracker.onChange = { [weak self] inside in
      self?.pointerInsideChanged(inside)
    }
    hoverTracker.onMoveInside = { [weak self] in
      self?.model.send(.pointerMoved)
    }
    model.onStateChange = { [weak self] state in
      self?.stateChanged(to: state)
    }
    observeSystemEvents()
    observeSettings()
    observeWidgets()
    applySettings()
    refreshFullScreenState()
    #if DEBUG
      observeDebugCommands()
    #endif
  }

  private func stateChanged(to state: NotchState) {
    updateHoverArea()
    host.panelOpenChanged(state.isOpen)
    // A light tap on the trackpad when the panel opens, like a physical detent.
    if state == .expanded && !lastState.isOpen && settings.hapticFeedback {
      NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    lastState = state
  }

  #if DEBUG
    /// Debug builds only: lets scripts open and close the panel for performance and leak
    /// checks (`scripts/` posts these distributed notifications).
    private func observeDebugCommands() {
      let center = DistributedNotificationCenter.default()
      observers.append(
        center.addObserver(
          forName: Notification.Name("io.github.muazfurkan.ljaspnotch.debug.open"), object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.model.send(.clicked) }
        })
      observers.append(
        center.addObserver(
          forName: Notification.Name("io.github.muazfurkan.ljaspnotch.debug.close"), object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.model.send(.reset) }
        })
    }
  #endif

  /// Re-places the panel whenever the screen setup, sleep state or space changes (N3).
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
  }

  /// Re-registers after every change, as `withObservationTracking` fires only once.
  /// (`Observations` would be simpler but crashes the Swift 6.2 compiler in CI.)
  private func observeSettings() {
    withObservationTracking {
      _ = settings.isPaused
      _ = settings.opensOnHover
      _ = settings.openDelay
      _ = settings.closeDelay
      _ = settings.hidesInFullScreen
      _ = settings.usesVirtualNotch
      _ = settings.isPreviewingAppearance
      _ = themes.current
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.applySettings()
        self?.observeSettings()
      }
    }
  }

  /// Live activities drive the peek state; layout changes create or remove widgets.
  private func observeWidgets() {
    withObservationTracking {
      _ = host.liveActivities.current?.id
      _ = host.layoutStore.layout
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.host.layoutChanged()
        self.model.send(.liveActivityChanged(self.host.liveActivities.current != nil))
        self.observeWidgets()
      }
    }
  }

  /// Closes the panel, e.g. before Settings opens to ask for a permission.
  func collapse() {
    model.send(.reset)
  }

  private func applySettings() {
    model.theme = themes.current
    model.opensOnHover = settings.opensOnHover
    model.openDelay = .milliseconds(Int(settings.openDelay * 1000))
    model.closeDelay = .milliseconds(Int(settings.closeDelay * 1000))
    layoutPanel()
    updatePreview()
  }

  /// Keeps the panel open while the Appearance settings are visible.
  private func updatePreview() {
    guard settings.isPreviewingAppearance != isPreviewing else { return }
    isPreviewing = settings.isPreviewingAppearance
    if isPreviewing {
      model.send(.clicked)
      if model.state == .expanded {
        model.send(.pinToggled)
      }
    } else {
      model.send(.reset)
    }
  }

  /// The notched screen, or with the virtual notch setting the main screen when no screen
  /// has a notch.
  private func targetScreen() -> (screen: NSScreen, geometry: NotchGeometry)? {
    let layout = NotchLayout(theme: themes.current)
    if let screen = NSScreen.notched, let geometry = screen.notchGeometry(layout: layout) {
      return (screen, geometry)
    }
    guard settings.usesVirtualNotch, let screen = NSScreen.screens.first else { return nil }
    return (screen, screen.virtualNotchGeometry(layout: layout))
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
        guard let target = self?.targetScreen() else {
          self?.setFullScreenActive(false)
          continue
        }
        let frame = target.screen.cgFrame
        let notchHeight = target.geometry.notchRect.height
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
    Log.notch.info("Full screen app on the panel's screen: \(active, privacy: .public)")
    layoutPanel()
  }

  /// Puts the panel under the notch, or hides it when paused, behind a full screen app or
  /// when there is no screen to show it on.
  func layoutPanel() {
    let hiddenByFullScreen = isFullScreenActive && settings.hidesInFullScreen
    guard !settings.isPaused, !hiddenByFullScreen, let geometry = targetScreen()?.geometry else {
      hidePanel()
      return
    }
    let panel = panel ?? makePanel()
    self.panel = panel
    if model.geometry != geometry || !panel.isVisible {
      model.geometry = geometry
      panel.setFrame(geometry.windowFrame, display: true)
      Log.notch.info(
        "Panel placed at \(String(describing: geometry.windowFrame), privacy: .public)")
    }
    panel.orderFrontRegardless()
    hoverTracker.start()
    updateHoverArea()
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
    let hostingView = NotchHostingView(rootView: NotchRootView(model: model, host: host))
    // The window size is fixed; SwiftUI must not resize it.
    hostingView.sizingOptions = []
    panel.contentView = hostingView
    return panel
  }
}
