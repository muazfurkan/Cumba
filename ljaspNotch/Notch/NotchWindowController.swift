import AppKit

/// Owns the notch panel: places it on the notched screen and connects it to the view model.
@MainActor
final class NotchWindowController {
  private let settings: AppSettings
  private let model = NotchViewModel()
  private var panel: NotchPanel?

  init(settings: AppSettings) {
    self.settings = settings
  }

  func start() {
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
    Log.notch.info("Panel placed at \(String(describing: geometry.windowFrame), privacy: .public)")
  }

  private func hidePanel() {
    model.send(.reset)
    panel?.orderOut(nil)
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
