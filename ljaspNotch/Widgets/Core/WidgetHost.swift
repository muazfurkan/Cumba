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
    updateActivation()
  }

  func panelOpenChanged(_ isOpen: Bool) {
    isPanelOpen = isOpen
    updateActivation()
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
            host.select(tab.id)
          } label: {
            Image(systemName: tab.symbol)
              .frame(width: 26, height: 22)
              .background(isSelected ? .white.opacity(0.18) : .clear, in: Capsule())
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .help(tab.title)
          .accessibilityLabel(tab.title)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
    } else {
      Text("ljaspNotch")
        .font(.headline)
    }
  }
}

/// The widgets of the selected tab side by side, sized by their units.
struct WidgetRow: View {
  let host: WidgetHost
  let secondary: Color

  var body: some View {
    let kinds = (host.selectedTab?.widgets ?? []).filter { host.registry.widget($0) != nil }
    if kinds.isEmpty {
      Text("This tab is empty. Add widgets in Settings.")
        .foregroundStyle(secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      GeometryReader { proxy in
        let spacing: CGFloat = 10
        let units = kinds.compactMap { host.registry.info(for: $0)?.size.units }.reduce(0, +)
        let unitWidth =
          (proxy.size.width - spacing * CGFloat(kinds.count - 1)) / CGFloat(max(units, 1))
        HStack(spacing: spacing) {
          ForEach(kinds, id: \.self) { kind in
            if let widget = host.registry.widget(kind), let info = host.registry.info(for: kind) {
              widget.makeView()
                .frame(width: unitWidth * CGFloat(info.size.units))
            }
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

  var body: some View {
    HStack(spacing: 0) {
      activity.leading
        .frame(width: sideWidth)
      Color.clear
        .frame(width: notchWidth)
      activity.trailing
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: sideWidth)
    }
    .font(.caption)
  }
}
