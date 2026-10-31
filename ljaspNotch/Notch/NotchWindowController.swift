import AppKit

/// Owns the notch panel: places it on the notched screen and connects it to the view model.
@MainActor
final class NotchWindowController {
  private let settings: AppSettings
  private let model = NotchViewModel()
  private let hoverTracker = HoverTracker()
  private var panel: NotchPanel?

  init(settings: AppSettings) {
    self.settings = settings
  }

  func start() {
    hoverTracker.onChange = { [weak self] inside in
      self?.pointerInsideChanged(inside)
    }
    model.onStateChange = { [weak self] _ in
      self?.updateHoverArea()
    }
    layoutPanel()
  }

  /// Puts the panel under the notch, or hides it when paused or no screen has a notch.
  func layoutPanel() {
    guard !settings.isPaused, let geometry = NSScreen.notched?.notchGeometry() else {
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
