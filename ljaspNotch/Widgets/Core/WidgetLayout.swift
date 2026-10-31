import Foundation

/// Tabs and the widgets in them, saved as layout.json. Each widget kind
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

  /// Width a tab holds before new widgets go to another tab, in size units.
  static let unitsPerTab = 6

  /// Adds kinds that are new in this app version, so updates show their new widgets once.
  /// Each goes to the first tab with room, or to a new "More" tab. Kinds the user removed
  /// stay removed.
  /// - Parameter kinds: Kinds of this app version with their width in units, in order.
  mutating func adoptNewKinds(_ kinds: [(kind: String, units: Int)]) {
    let units = Dictionary(
      kinds.map { ($0.kind, $0.units) }, uniquingKeysWith: { first, _ in first })
    func used(_ tab: Tab) -> Int {
      tab.widgets.reduce(0) { $0 + (units[$1] ?? 1) }
    }
    for (kind, width) in kinds where !seenKinds.contains(kind) && !contains(kind) {
      if tabs.isEmpty {
        tabs.append(Self.homeTab(widgets: []))
      }
      if let index = tabs.firstIndex(where: { used($0) + width <= Self.unitsPerTab }) {
        tabs[index].widgets.append(kind)
      } else {
        tabs.append(Self.moreTab(number: tabs.count, widgets: [kind]))
      }
    }
    seenKinds = Array(Set(seenKinds).union(kinds.map(\.kind))).sorted()
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

  static func moreTab(number: Int, widgets: [String]) -> Tab {
    Tab(
      id: "more-\(number)", title: String(localized: "More", comment: "Extra panel tab"),
      symbol: number > 1 ? "square.grid.3x3" : "square.grid.2x2", widgets: widgets)
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
