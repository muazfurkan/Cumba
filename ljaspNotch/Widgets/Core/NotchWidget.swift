import SwiftUI

/// Width of a widget in the panel, in units of the tab's row (SPEC § 7).
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

  init(context: WidgetContext)

  var size: WidgetSize { get }

  func makeView() -> AnyView
  func makeSettingsView() -> AnyView?

  /// Called while the widget is on screen. Cameras, sampling and similar resources are
  /// only used between `activate()` and `deactivate()`.
  func activate()
  func deactivate()

  /// Called when the widget is removed from the layout; stop any background work.
  func shutdown()
}

extension NotchWidget {
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
  /// Opens the Settings window, e.g. to ask for a permission from there instead of
  /// from the panel.
  let openSettings: @MainActor () -> Void
}

/// Rounded card that every widget draws its content in.
struct WidgetCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
