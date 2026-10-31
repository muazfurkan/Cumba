import Foundation

/// Tabs and the widgets in them, saved as layout.json (SPEC § 7). Each widget kind
/// appears in at most one tab.
struct WidgetLayout: Codable, Equatable, Sendable {
  struct Tab: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var symbol: String
    var widgets: [String]
  }

  var version = 1
  var tabs: [Tab]
  /// Kinds that existed when the layout was last saved. A kind missing here is new in this
  /// version of the app and gets added to the first tab once.
  var seenKinds: [String] = []

  init(tabs: [Tab], seenKinds: [String] = []) {
    self.tabs = tabs
    self.seenKinds = seenKinds
  }

  /// Symbols offered for tabs in Settings.
  static let tabSymbols = [
    "house", "star", "music.note", "calendar", "timer", "bolt", "terminal", "tray",
    "camera", "cloud.sun", "square.grid.2x2",
  ]

  /// Adds kinds that are new in this app version to the first tab, so updates show their
  /// new widgets once. Kinds the user removed stay removed.
  mutating func adoptNewKinds(_ kinds: [String]) {
    let new = kinds.filter { !seenKinds.contains($0) && !contains($0) }
    if !new.isEmpty {
      if tabs.isEmpty {
        tabs.append(Self.homeTab(widgets: []))
      }
      tabs[0].widgets.append(contentsOf: new)
    }
    seenKinds = Array(Set(seenKinds).union(kinds)).sorted()
  }

  /// Drops kinds this version doesn't know and duplicates across tabs.
  mutating func removeUnknown(knownKinds: [String]) {
    var placed = Set<String>()
    for index in tabs.indices {
      tabs[index].widgets = tabs[index].widgets.filter { kind in
        knownKinds.contains(kind) && placed.insert(kind).inserted
      }
    }
  }

  func contains(_ kind: String) -> Bool {
    tabs.contains { $0.widgets.contains(kind) }
  }

  func tab(containing kind: String) -> Tab? {
    tabs.first { $0.widgets.contains(kind) }
  }

  static func homeTab(widgets: [String]) -> Tab {
    Tab(
      id: "home", title: String(localized: "Home", comment: "Default panel tab"),
      symbol: "house", widgets: widgets)
  }
}

extension WidgetLayout {
  private enum CodingKeys: String, CodingKey {
    case version, tabs, seenKinds
  }

  /// Tolerant like themes: a broken tab list falls back to no tabs, which `adoptNewKinds`
  /// then fills with the default widgets.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
    tabs = (try? container.decodeIfPresent([Tab].self, forKey: .tabs)) ?? []
    seenKinds = (try? container.decodeIfPresent([String].self, forKey: .seenKinds)) ?? []
  }
}
