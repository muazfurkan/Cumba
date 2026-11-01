import AppKit
import SwiftUI

/// Owns the notch panel: places it on the right screen and connects it to the view model,
/// the settings and the current theme.
@MainActor
final class NotchWindowController {
  private let settings: AppSettings
  private let themes: ThemeStore
  private let host: WidgetHost
  private let panelControl: PanelControl
  private let model = NotchViewModel()
  private let hoverTracker = HoverTracker()
  private let tabSwipe = TabSwipeMonitor()
  private var panel: NotchPanel?
  private var observers: [NSObjectProtocol] = []
  private var isObservingMenus = false
  private var fullScreenTask: Task<Void, Never>?
  /// A full screen app covers the panel's screen.
  private var isFullScreenActive = false
  private var isPreviewing = false
  private var shownPreview: NotchPreview?
  private static let previewActivityID = "preview"
  private var lastState = NotchState.closed
  /// A menu of this app is open (the notch's right-click menu or a widget's menu); leaving
  /// the notch then doesn't close the panel.
  private var isMenuOpen = false
  /// Opens the Settings window (set by the app delegate).
  var openSettings: (() -> Void)?

  /// The panel was pinned open for a widget (see `PanelControl.keepOpen`).
  private var isKeptOpenForWidget = false

  init(settings: AppSettings, themes: ThemeStore, panelControl: PanelControl, host: WidgetHost) {
    self.settings = settings
    self.themes = themes
    self.panelControl = panelControl
    self.host = host
  }

  func start() {
    hoverTracker.onChange = { [weak self] inside in
      self?.pointerInsideChanged(inside)
    }
    hoverTracker.onMoveInside = { [weak self] in
      self?.model.send(.pointerMoved)
    }
    hoverTracker.onMove = { [weak self] in
      self?.followPointerScreen()
    }
    model.onStateChange = { [weak self] state in
      self?.stateChanged(to: state)
    }
    startTabSwipes()
    connectPanelControl()
    observeSystemEvents()
    observeSettings()
    observeWidgets()
    applySettings()
    refreshFullScreenState()
    #if DEBUG
      observeDebugCommands()
    #endif
  }

  /// Two fingers sliding sideways on the open panel move between tabs, with the same light
  /// tap as opening it. Not while the gallery, which scrolls sideways, is open.
  private func startTabSwipes() {
    tabSwipe.window = { [weak self] in self?.panel }
    tabSwipe.isEnabled = { [weak self] in
      guard let self else { return false }
      return model.state.isOpen && !host.isShowingGallery && !host.isEditing
        && host.permissionBanner == nil
    }
    tabSwipe.onDrag = { [weak self] travel in
      self?.host.dragPages(to: travel)
    }
    tabSwipe.onEnd = { [weak self] travel in
      guard let self, host.endPageDrag(travel: travel), settings.hapticFeedback else { return }
      NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    tabSwipe.start()
  }

  private func stateChanged(to state: NotchState) {
    updateHoverArea()
    // A closed panel must not keep keyboard focus (after typing in Notes); ordering it out
    // and in again hands focus back to the app in front.
    if !state.isOpen, let panel, panel.isKeyWindow {
      panel.orderOut(nil)
      panel.orderFrontRegardless()
    }
    host.panelOpenChanged(state.isOpen)
    // A light tap on the trackpad when the panel opens, like a physical detent.
    if state == .expanded && !lastState.isOpen {
      if settings.hapticFeedback {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
      }
      NotificationCenter.default.post(name: .notchPanelDidOpen, object: nil)
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
    // Back from fast user switching.
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main,
        using: relayout))
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
      _ = settings.panelScreen
      _ = settings.tabBarStyle
      _ = settings.widgetStyle
      _ = settings.openingTab
      _ = settings.opensAgentTab
      _ = settings.panelSize
      _ = settings.isPreviewingAppearance
      _ = settings.notchPreview
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
      _ = host.selectedTab?.id
      _ = host.isShowingGallery
      _ = host.isEditing
      _ = host.permissionBanner?.id
      // What an agent shows can make its tab taller.
      _ = host.claude.sessions
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.host.layoutChanged()
        self.model.isShowingNotification = self.host.liveActivities.current?.notification != nil
        self.model.send(.liveActivityChanged(self.host.liveActivities.current != nil))
        self.updateGeometry()
        self.observeWidgets()
      }
    }
  }

  private func connectPanelControl() {
    panelControl.keepOpen = { [weak self] keep in
      guard let self else { return }
      if keep, model.state == .expanded {
        isKeptOpenForWidget = true
        model.send(.pinToggled)
      } else if !keep, isKeptOpenForWidget {
        isKeptOpenForWidget = false
        if model.state == .pinned {
          model.send(.pinToggled)
        }
      }
    }
    panelControl.hideFromCapture = { [weak self] hide in
      self?.panel?.sharingType = hide ? .none : .readOnly
    }
    panelControl.close = { [weak self] in
      self?.model.send(.reset)
    }
    // While someone types in the panel it stays open; it closes once focus moves away.
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
      ) { [weak self] notification in
        let window = notification.object as? NSWindow
        MainActor.assumeIsolated {
          guard let self, window === self.panel else { return }
          self.menuClosed()
        }
      })
  }

  /// Closes the panel, e.g. before Settings opens to ask for a permission.
  func collapse() {
    model.send(.reset)
  }

  /// Throws the panel away and builds it again, in case it ever ends up in a bad place.
  func resetPanel() {
    hidePanel()
    panel?.close()
    panel = nil
    model.geometry = nil
    layoutPanel()
  }

  /// Settings and Quit on the notch itself, for when the menu bar icon is hidden behind it.
  private func makeContextMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(
      ClosureMenuItem(
        title: String(localized: "Settings…", comment: "Menu item that opens the Settings window")
      ) { [weak self] in
        self?.model.send(.reset)
        self?.openSettings?()
      })
    menu.addItem(
      ClosureMenuItem(
        title: String(localized: "Reset Panel", comment: "Menu item that rebuilds the notch panel")
      ) { [weak self] in self?.resetPanel() })
    menu.addItem(.separator())
    menu.addItem(
      ClosureMenuItem(title: String(localized: "Quit Cumba")) { NSApp.terminate(nil) })
    return menu
  }

  /// Any menu keeps the panel open while it's being tracked. Registered once, even when
  /// Reset Panel builds a new panel.
  private func observeMenus() {
    guard !isObservingMenus else { return }
    isObservingMenus = true
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.isMenuOpen = true }
      })
    observers.append(
      center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.menuClosed() }
      })
  }

  /// The pointer may have left while a menu was open or the panel had keyboard focus;
  /// close the panel then.
  private func menuClosed() {
    isMenuOpen = false
    guard panel?.isKeyWindow != true else { return }
    hoverTracker.update()
    if !hoverTracker.isInside {
      panel?.ignoresMouseEvents = true
      model.send(.pointerExited)
    }
  }

  private func applySettings() {
    model.theme = themes.current
    model.textScale = settings.panelSize.textScale
    model.tabBarStyle = settings.tabBarStyle
    model.widgetStyle = settings.widgetStyle
    host.openingTab = settings.openingTab
    host.opensAgentTab = settings.opensAgentTab
    model.opensOnHover = settings.opensOnHover
    model.openDelay = .milliseconds(Int(settings.openDelay * 1000))
    model.closeDelay = .milliseconds(Int(settings.closeDelay * 1000))
    layoutPanel()
    updatePreview()
  }

  /// Keeps the panel open while the Appearance settings are visible. While a size slider
  /// for the closed notch or the space beside it is dragged, shows that state instead.
  private func updatePreview() {
    let preview = settings.isPreviewingAppearance ? settings.notchPreview : nil
    let wantsOpen = settings.isPreviewingAppearance && preview == nil
    guard wantsOpen != isPreviewing || preview != shownPreview else { return }
    isPreviewing = wantsOpen
    shownPreview = preview
    model.restsClosed = preview == .closed
    if preview == .peek && host.liveActivities.current == nil {
      // A volume level as a sample of what shows beside the notch.
      host.liveActivities.show(
        LiveActivity(
          id: Self.previewActivityID, priority: .volume,
          leading: AnyView(LevelSymbol(name: "speaker.wave.2.fill", label: Text("Volume"))),
          trailing: AnyView(LevelBar(level: 0.6, label: Text("Volume")))))
    } else if preview != .peek {
      host.liveActivities.dismiss(Self.previewActivityID)
    }
    if wantsOpen {
      model.send(.clicked)
      if model.state == .expanded {
        model.send(.pinToggled)
      }
    } else {
      model.send(.reset)
    }
  }

  private func targetScreen() -> (screen: NSScreen, geometry: NotchGeometry)? {
    NotchScreenLayout.target(
      settings: settings, host: host, layoutStore: host.layoutStore,
      screenUnderPointer: Self.screenUnderPointer)
  }

  static var screenUnderPointer: NSScreen? {
    let location = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
  }

  /// With "the display with the pointer", moves the panel when the pointer changes screens.
  private func followPointerScreen() {
    guard settings.panelScreen == .pointer, !model.state.isOpen,
      let screen = Self.screenUnderPointer, let geometry = model.geometry,
      !NSMouseInRect(
        NSPoint(x: geometry.windowFrame.midX, y: geometry.windowFrame.midY),
        screen.frame, false)
    else { return }
    layoutPanel()
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

  /// Follows what the panel shows (tab, gallery, live activity) without re-placing the
  /// window unless its frame changes.
  private func updateGeometry() {
    guard let panel, panel.isVisible, let geometry = targetScreen()?.geometry,
      geometry != model.geometry
    else { return }
    let frameChanged = geometry.windowFrame != model.geometry?.windowFrame
    model.geometry = geometry
    if frameChanged {
      panel.setFrame(geometry.windowFrame, display: true)
    }
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
    if !inside && (isMenuOpen || panel?.isKeyWindow == true) {
      return
    }
    panel?.ignoresMouseEvents = !inside
    host.liveActivities.isPointerOver = inside
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
    hostingView.makeContextMenu = { [weak self] in self?.makeContextMenu() ?? NSMenu() }
    observeMenus()
    panel.contentView = hostingView
    return panel
  }
}

extension Notification.Name {
  /// Posted when the panel opens, e.g. for the welcome window's "try it" step.
  static let notchPanelDidOpen = Notification.Name("io.github.muazfurkan.ljaspnotch.panelDidOpen")
}
