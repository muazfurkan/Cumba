import Observation

/// Maps widget kinds to their types and owns the live instances. Only widgets that are in
/// the layout exist; removing one from the layout shuts it down.
@MainActor
@Observable
final class WidgetRegistry {
  @ObservationIgnored let types: [any NotchWidget.Type]
  @ObservationIgnored private let context: WidgetContext
  private(set) var instances: [String: any NotchWidget] = [:]

  init(context: WidgetContext, types: [any NotchWidget.Type]) {
    self.context = context
    self.types = types
  }

  /// Every widget of this app version, in default order. A new widget is one more entry.
  static func standard(context: WidgetContext) -> WidgetRegistry {
    WidgetRegistry(
      context: context,
      types: [
        MediaWidget.self, ClaudeCodeWidget.self, CalendarWidget.self, TimerWidget.self,
        BatteryWidget.self, TrayWidget.self, MirrorWidget.self, WeatherWidget.self,
        ShortcutsWidget.self, SystemStatsWidget.self,
      ])
  }

  var kinds: [String] { types.map { $0.kind } }

  /// Name and symbol of every widget kind, for Settings.
  var infos: [WidgetInfo] {
    types.map { WidgetInfo(kind: $0.kind, title: $0.title, symbol: $0.symbol, size: $0.size) }
  }

  func info(for kind: String) -> WidgetInfo? {
    infos.first { $0.kind == kind }
  }

  func widget(_ kind: String) -> (any NotchWidget)? {
    instances[kind]
  }

  /// Creates widgets that joined the layout and shuts down those that left it.
  func sync(with layout: WidgetLayout) {
    let wanted = Set(layout.tabs.flatMap(\.widgets))
    for (kind, widget) in instances where !wanted.contains(kind) {
      widget.shutdown()
      instances[kind] = nil
    }
    for type in types where wanted.contains(type.kind) && instances[type.kind] == nil {
      instances[type.kind] = type.init(context: context)
    }
  }
}

/// Plain description of a widget kind. Views use this instead of the widget types.
struct WidgetInfo: Identifiable, Equatable, Sendable {
  let kind: String
  let title: String
  let symbol: String
  let size: WidgetSize

  var id: String { kind }
}
