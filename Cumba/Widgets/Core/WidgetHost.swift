import Observation
import SwiftUI

/// What the expanded panel shows: the tabs of the layout and the widgets in the selected
/// one. Activates widgets only while they are on screen.
@MainActor
@Observable
final class WidgetHost {
  let layoutStore: LayoutStore
  let registry: WidgetRegistry
  let liveActivities: LiveActivityCenter
  let claude: ClaudeCodeService
  private(set) var selectedTabID: String?
  /// The widget gallery shows in the panel instead of the open tab's widgets.
  private(set) var isShowingGallery = false

  @ObservationIgnored private var activeKinds: Set<String> = []
  @ObservationIgnored private var isPanelOpen = false

  init(
    layoutStore: LayoutStore, registry: WidgetRegistry, liveActivities: LiveActivityCenter,
    claude: ClaudeCodeService
  ) {
    self.layoutStore = layoutStore
    self.registry = registry
    self.liveActivities = liveActivities
    self.claude = claude
  }

  /// A pending Claude Code request shows above the widgets unless the Claude Code widget
  /// is already on screen.
  var permissionBanner: PermissionBroker.Request? {
    guard selectedTab?.widgets.contains(ClaudeCodeWidget.kind) != true else { return nil }
    return claude.permissions.pending.first
  }

  var tabs: [WidgetLayout.Tab] { layoutStore.layout.tabs }

  var selectedTab: WidgetLayout.Tab? {
    tabs.first { $0.id == selectedTabID } ?? tabs.first
  }

  func select(_ tabID: String) {
    selectedTabID = tabID
    isShowingGallery = false
    updateActivation()
  }

  func panelOpenChanged(_ isOpen: Bool) {
    isPanelOpen = isOpen
    if !isOpen {
      isShowingGallery = false
    }
    updateActivation()
  }

  func showGallery(_ isShowing: Bool) {
    isShowingGallery = isShowing
  }

  /// Size units still free in the open tab.
  var freeUnits: Int {
    let used = (selectedTab?.widgets ?? []).compactMap { registry.info(for: $0)?.size.units }
    return max(0, WidgetLayout.unitsPerTab - used.reduce(0, +))
  }

  /// Widgets that aren't in any tab yet.
  var addableInfos: [WidgetInfo] {
    registry.infos.filter { !layoutStore.layout.contains($0.kind) }
  }

  /// Takes a widget out of the panel; the gallery can add it back.
  func remove(_ kind: String) {
    layoutStore.remove(kind)
  }

  /// Adds a widget to the open tab and closes the gallery.
  func add(_ kind: String) {
    guard let tab = selectedTab else { return }
    layoutStore.add(kind, to: tab.id)
    isShowingGallery = false
  }

  /// Call after the layout changed: creates or shuts down widgets and re-activates.
  func layoutChanged() {
    registry.sync(with: layoutStore.layout)
    updateActivation()
  }

  private func updateActivation() {
    let visible = isPanelOpen ? Set(selectedTab?.widgets ?? []) : []
    for kind in activeKinds.subtracting(visible) {
      registry.widget(kind)?.deactivate()
    }
    for kind in visible.subtracting(activeKinds) {
      registry.widget(kind)?.activate()
    }
    activeKinds = visible
  }
}

/// Tab buttons for the top band of the expanded panel.
struct WidgetTabBar: View {
  let host: WidgetHost

  var body: some View {
    if host.tabs.count > 1 {
      HStack(spacing: 4) {
        ForEach(host.tabs) { tab in
          let isSelected = tab.id == host.selectedTab?.id
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              host.select(tab.id)
            }
          } label: {
            Image(systemName: tab.symbol)
              .symbolVariant(isSelected ? .fill : .none)
          }
          .buttonStyle(PanelButtonStyle(isSelected: isSelected))
          .help(tab.title)
          .accessibilityLabel(tab.title)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
    } else {
      Text("Cumba")
        .font(.headline)
    }
  }
}

/// The widgets of the selected tab side by side, sized by their units. Room left in the tab
/// shows a narrow "+" tile, and an empty tab is one big tile; both open the gallery.
struct WidgetRow: View {
  let host: WidgetHost
  let secondary: Color

  private static let addTileWidth: CGFloat = 34

  var body: some View {
    let kinds = (host.selectedTab?.widgets ?? []).filter { host.registry.widget($0) != nil }
    if kinds.isEmpty {
      AddWidgetTile(fillsTab: true) { host.showGallery(true) }
    } else {
      GeometryReader { proxy in
        let spacing: CGFloat = 10
        let showsAdd = host.freeUnits > 0 && !host.addableInfos.isEmpty
        let addRoom = showsAdd ? Self.addTileWidth + spacing : 0
        let units = kinds.compactMap { host.registry.info(for: $0)?.size.units }.reduce(0, +)
        let unitWidth =
          (proxy.size.width - addRoom - spacing * CGFloat(kinds.count - 1))
          / CGFloat(max(units, 1))
        HStack(spacing: spacing) {
          ForEach(kinds, id: \.self) { kind in
            if let widget = host.registry.widget(kind), let info = host.registry.info(for: kind) {
              widget.makeView()
                .frame(width: unitWidth * CGFloat(info.size.units))
                .contextMenu {
                  Button("Remove \(info.title)") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                      host.remove(kind)
                    }
                  }
                }
                .accessibilityAction(named: Text("Remove \(info.title)")) { host.remove(kind) }
            }
          }
          if showsAdd {
            AddWidgetTile(fillsTab: false) { host.showGallery(true) }
              .frame(width: Self.addTileWidth)
          }
        }
      }
    }
  }
}

/// Live activity on both sides of the closed notch.
struct PeekView: View {
  let activity: LiveActivity
  let notchWidth: CGFloat
  let sideWidth: CGFloat
  let height: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      // Clipped, so nothing can slide under the camera housing where it can't be seen.
      activity.leading
        .frame(width: sideWidth)
        .clipped()
      Color.clear
        .frame(width: notchWidth)
      activity.trailing
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: sideWidth)
        .clipped()
    }
    .font(.caption)
    .environment(\.peekHeight, height)
    .accessibilityElement(children: .combine)
  }
}

extension EnvironmentValues {
  /// Height of the closed notch, so live activities can size their content to it.
  @Entry var peekHeight: CGFloat = 32
}
