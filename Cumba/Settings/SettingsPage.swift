import SwiftUI

/// A page of the Settings window, listed in its sidebar.
enum SettingsPage: Hashable, Identifiable, Sendable {
  case general
  case appearance
  case displays
  case behavior
  case indicators
  case permissions
  /// Tabs and the widget gallery.
  case widgets
  /// One widget's own settings.
  case widget(String)
  case agents
  case connections

  /// The pages at the top of the sidebar, then those under Features.
  static let main: [SettingsPage] = [
    .general, .appearance, .displays, .behavior, .indicators, .permissions,
  ]
  static let features: [SettingsPage] = [.agents, .connections]

  var id: String {
    switch self {
    case .general: "general"
    case .appearance: "appearance"
    case .displays: "displays"
    case .behavior: "behavior"
    case .indicators: "indicators"
    case .permissions: "permissions"
    case .widgets: "widgets"
    case .widget(let kind): "widget." + kind
    case .agents: "agents"
    case .connections: "connections"
    }
  }

  init?(id: String) {
    if id.hasPrefix("widget.") {
      self = .widget(String(id.dropFirst("widget.".count)))
      return
    }
    guard let page = (Self.main + Self.features + [.widgets]).first(where: { $0.id == id })
    else { return nil }
    self = page
  }
}

/// How a page looks in the sidebar and at its top.
struct SettingsPageInfo {
  let title: String
  let summary: String
  let symbol: String
  let color: Color
  /// Extra words the sidebar search finds the page by.
  var keywords: [String] = []
}

extension SettingsPage {
  @MainActor
  func info(registry: WidgetRegistry) -> SettingsPageInfo {
    switch self {
    case .general:
      SettingsPageInfo(
        title: String(localized: "General", comment: "Settings page"),
        summary: String(
          localized: "Start Cumba with your Mac, keep it up to date and see how it's doing.",
          comment: "Settings page description"),
        symbol: "gearshape.fill", color: .gray,
        keywords: [String(localized: "Updates"), String(localized: "Launch at login")])
    case .appearance:
      SettingsPageInfo(
        title: String(localized: "Appearance", comment: "Settings page"),
        summary: String(
          localized: "Pick a theme and the tabs' style, size the panel and make your own look.",
          comment: "Settings page description"),
        symbol: "paintbrush.fill", color: .indigo,
        keywords: [
          String(localized: "Theme"), String(localized: "Tabs"), String(localized: "Panel Size"),
        ])
    case .displays:
      SettingsPageInfo(
        title: String(localized: "Displays", comment: "Settings page"),
        summary: String(
          localized: "Choose the display the panel is on and what happens in full screen.",
          comment: "Settings page description"),
        symbol: "display", color: .blue,
        keywords: [String(localized: "Full screen"), String(localized: "Virtual notch")])
    case .behavior:
      SettingsPageInfo(
        title: String(localized: "Behavior", comment: "Settings page"),
        summary: String(
          localized: "How the panel opens and closes.", comment: "Settings page description"),
        symbol: "hand.point.up.left.fill", color: .orange,
        keywords: [String(localized: "Open delay"), String(localized: "Haptic feedback")])
    case .indicators:
      SettingsPageInfo(
        title: String(localized: "Indicators", comment: "Settings page"),
        summary: String(
          localized: "Volume, brightness, battery and the microphone or camera, beside the notch.",
          comment: "Settings page description"),
        symbol: "dial.medium.fill", color: .pink,
        keywords: [
          String(localized: "Volume"), String(localized: "Brightness"),
          String(localized: "Battery"),
        ])
    case .permissions:
      SettingsPageInfo(
        title: String(localized: "Permissions", comment: "Settings page"),
        summary: String(
          localized: "What Cumba may use, and one click to ask or to open System Settings.",
          comment: "Settings page description"),
        symbol: "checkmark.shield.fill", color: .green)
    case .widgets:
      SettingsPageInfo(
        title: String(localized: "Widgets", comment: "Settings page"),
        summary: String(
          localized: "Your tabs and the widgets in them, and every widget there is.",
          comment: "Settings page description"),
        symbol: "square.grid.2x2.fill", color: .teal,
        keywords: [String(localized: "Tabs"), String(localized: "Widget Gallery")])
    case .widget(let kind):
      Self.widgetInfo(kind, registry: registry)
    case .agents:
      SettingsPageInfo(
        title: String(localized: "Agents", comment: "Settings page"),
        summary: String(
          localized: "Follow Claude Code and Codex in the notch and answer their requests.",
          comment: "Settings page description"),
        symbol: "sparkles", color: .purple,
        keywords: ["Claude Code", "Codex", String(localized: "Hooks")])
    case .connections:
      SettingsPageInfo(
        title: String(localized: "Connections", comment: "Settings page"),
        summary: String(
          localized: "The YouTube extension and your own scripts.",
          comment: "Settings page description"),
        symbol: "point.3.connected.trianglepath.dotted", color: .cyan,
        keywords: ["YouTube", String(localized: "Scripts")])
    }
  }

  @MainActor
  private static func widgetInfo(_ kind: String, registry: WidgetRegistry) -> SettingsPageInfo {
    let info = registry.info(for: kind)
    return SettingsPageInfo(
      title: info?.title ?? kind, summary: info?.summary ?? "",
      symbol: info?.symbol ?? "square.dashed", color: widgetColors[kind] ?? .teal)
  }

  private static let widgetColors: [String: Color] = [
    "media": .pink, "calendar": .red, "weather": .blue, "clipboard": .teal, "notes": .yellow,
    "timer": .orange, "pomodoro": .orange, "teleprompter": .red, "tray": .indigo,
    "mirror": .gray, "shortcuts": .purple, "system-stats": .green, "battery": .green,
    "keep-awake": .brown, "claude-code": .purple,
  ]
}
