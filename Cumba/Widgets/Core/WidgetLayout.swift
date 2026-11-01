import Foundation

/// Tabs and the widgets in them, saved as layout.json. A widget kind appears at most once
/// per tab, but can be in several tabs; they share one instance, and only one tab is on
/// screen at a time.
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

  /// Size units a tab holds at the panel's own width. A tab can hold more while the panel
  /// can grow wider on the screen; see `capacity(panelWidth:screenWidth:)`.
  static let unitsPerTab = 6
  /// The open panel's side padding, and the gap between widgets.
  static let panelPadding: CGFloat = 56
  static let widgetSpacing: CGFloat = 10
  /// Room kept free on each side of the screen when the panel grows past its own width.
  static let screenMargin: CGFloat = 40

  /// Width of one size unit in a panel `panelWidth` wide.
  static func unitWidth(panelWidth: CGFloat) -> CGFloat {
    (panelWidth - panelPadding - widgetSpacing * CGFloat(unitsPerTab - 1)) / CGFloat(unitsPerTab)
  }

  /// Units side by side that fit on a screen: each keeps its width, and the panel grows up to
  /// the screen's width less a margin on each side. Never fewer than `unitsPerTab`.
  static func capacity(panelWidth: CGFloat, screenWidth: CGFloat) -> Int {
    let unit = unitWidth(panelWidth: panelWidth)
    let room = screenWidth - screenMargin * 2 - panelPadding + widgetSpacing
    return max(unitsPerTab, Int((room / (unit + widgetSpacing)).rounded(.down)))
  }

  /// Places kinds this layout hasn't seen before: those in `defaults` (all when `nil`) go to
  /// the first tab with room, or to a new "More" tab; the rest only become known, so they
  /// wait in the widget gallery. Kinds the user removed stay removed.
  /// - Parameters:
  ///   - kinds: Kinds of this app version with their width in units, in order.
  ///   - defaults: Kinds that a new or updated layout gets automatically.
  mutating func adoptNewKinds(_ kinds: [(kind: String, units: Int)], defaults: Set<String>? = nil) {
    let widths = Dictionary(
      kinds.map { ($0.kind, $0.units) }, uniquingKeysWith: { first, _ in first })
    for (kind, width) in kinds where !seenKinds.contains(kind) {
      if defaults?.contains(kind) ?? true {
        place(kind, units: width, widths: widths)
      }
    }
    seenKinds = Array(Set(seenKinds).union(kinds.map(\.kind))).sorted()
    if tabs.isEmpty {
      tabs.append(Self.homeTab(widgets: []))
    }
  }

  /// Puts a kind in the first tab with room, or in a new "More" tab.
  mutating func place(
    _ kind: String, units: Int, widths: [String: Int], capacity: Int = unitsPerTab
  ) {
    guard !contains(kind) else { return }
    func used(_ tab: Tab) -> Int {
      tab.widgets.reduce(0) { $0 + (widths[$1] ?? 1) }
    }
    if tabs.isEmpty {
      tabs.append(Self.homeTab(widgets: []))
    }
    if let index = tabs.firstIndex(where: { used($0) + units <= capacity }) {
      tabs[index].widgets.append(kind)
    } else {
      tabs.append(Self.moreTab(number: tabs.count, widgets: [kind]))
    }
  }

  /// Drops kinds this version doesn't know and duplicates within a tab.
  mutating func removeUnknown(knownKinds: [String]) {
    for index in tabs.indices {
      var placed = Set<String>()
      tabs[index].widgets = tabs[index].widgets.filter { kind in
        knownKinds.contains(kind) && placed.insert(kind).inserted
      }
    }
  }

  func contains(_ kind: String) -> Bool {
    tabs.contains { $0.widgets.contains(kind) }
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
