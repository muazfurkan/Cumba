import SwiftUI

/// Width of a widget in the panel, in units of the tab's row.
enum WidgetSize: String, Codable, Sendable {
  case compact
  case regular
  case wide

  var units: Int {
    switch self {
    case .compact: 1
    case .regular: 2
    case .wide: 3
    }
  }
}

/// A piece of content in the expanded panel. There is one shared instance per kind,
/// identified by `kind`; adding a widget means a new folder and one line in
/// `WidgetRegistry.standard`.
@MainActor
protocol NotchWidget: AnyObject {
  /// Stable identifier saved in layout.json, e.g. "calendar".
  static var kind: String { get }
  /// Name shown in Settings.
  static var title: String { get }
  /// SF Symbol shown in Settings.
  static var symbol: String { get }
  static var size: WidgetSize { get }
  /// One line for the widget gallery in Settings.
  static var summary: String { get }
  /// Part of the layout of a new installation. Everything else starts in the gallery.
  static var addedByDefault: Bool { get }

  init(context: WidgetContext)

  func makeView() -> AnyView
  func makeSettingsView() -> AnyView?
  /// Height the view needs for what it shows now at this width; nil fits any height.
  func preferredContentHeight(width: CGFloat, textScale: CGFloat, isDetailed: Bool) -> CGFloat?

  /// Called while the widget is on screen. Cameras, sampling and similar resources are
  /// only used between `activate()` and `deactivate()`.
  func activate()
  func deactivate()

  /// Called when the widget is removed from the layout; stop any background work.
  func shutdown()
}

extension NotchWidget {
  static var addedByDefault: Bool { false }
}

extension NotchWidget {
  /// Height the widget's view needs for what it shows now at this width, when the panel's
  /// own height may be too short; nil fits any height.
  func preferredContentHeight(width: CGFloat, textScale: CGFloat, isDetailed: Bool) -> CGFloat? {
    nil
  }
  func makeSettingsView() -> AnyView? { nil }
  func activate() {}
  func deactivate() {}
  func shutdown() {}
}

/// What widgets may use from the app.
@MainActor
struct WidgetContext {
  let liveActivities: LiveActivityCenter
  let media: MediaCoordinator
  let claude: ClaudeCodeService
  /// Lets a widget keep the panel open or hide it from screen capture.
  var panel = PanelControl()
  /// Opens the Settings window, e.g. to ask for a permission from there instead of
  /// from the panel.
  let openSettings: @MainActor (SettingsPage) -> Void
}

/// Rounded card that every widget draws its content in.
struct WidgetCard<Content: View>: View {
  /// Optional color that glows from the top left, e.g. from album art.
  var tint: Color?
  @ViewBuilder let content: Content

  init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
    self.tint = tint
    self.content = content()
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    content
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background {
        ZStack {
          shape.fill(.white.opacity(0.07))
          if let tint {
            shape.fill(
              RadialGradient(
                colors: [tint.opacity(0.45), tint.opacity(0)], center: .topLeading,
                startRadius: 0, endRadius: 220))
          }
          shape.strokeBorder(.white.opacity(0.06), lineWidth: 1)
        }
        .animation(.smooth(duration: 0.6), value: tint)
      }
  }
}

/// What a widget may ask of the panel itself. The window controller fills in the actions.
@MainActor
final class PanelControl {
  /// Keeps the panel open while `true`, e.g. while the teleprompter runs.
  var keepOpen: (Bool) -> Void = { _ in }
  /// Leaves the panel out of screenshots, recordings and screen sharing while `true`.
  var hideFromCapture: (Bool) -> Void = { _ in }
  /// Closes the panel, e.g. on Escape in a text field.
  var close: () -> Void = {}
}
