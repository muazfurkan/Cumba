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
  /// The open tab's editor shows instead of its widgets.
  private(set) var isEditing = false

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
    // While an agent works, opening the panel shows the tab with its widget.
    if isOpen, claude.sessions.contains(where: \.isActive),
      selectedTab?.widgets.contains(ClaudeCodeWidget.kind) != true,
      let tab = tabs.first(where: { $0.widgets.contains(ClaudeCodeWidget.kind) })
    {
      selectedTabID = tab.id
    }
    if !isOpen {
      isShowingGallery = false
      isEditing = false
    }
    updateActivation()
  }

  func showGallery(_ isShowing: Bool) {
    isShowingGallery = isShowing
    if isShowing {
      isEditing = false
    }
  }

  func setEditing(_ editing: Bool) {
    isEditing = editing
    if editing {
      isShowingGallery = false
    }
  }

  /// Adds a tab at the end and opens it, still editing.
  func addTab() {
    let id = layoutStore.addTab(title: String(localized: "New Tab", comment: "Default tab name"))
    select(id)
  }

  /// Deletes the open tab and opens the first one. The last tab can't be deleted.
  func deleteSelectedTab() {
    guard tabs.count > 1, let tab = selectedTab else { return }
    layoutStore.removeTab(tab.id)
    if let first = tabs.first {
      select(first.id)
    }
  }

  /// Moves the open tab one place left (-1) or right (+1).
  func moveSelectedTab(by offset: Int) {
    guard let index = tabs.firstIndex(where: { $0.id == selectedTab?.id }) else { return }
    let target = index + offset
    guard tabs.indices.contains(target) else { return }
    layoutStore.moveTabs(from: IndexSet(integer: index), to: offset > 0 ? target + 1 : target)
  }

  /// Moves a widget of the open tab one place left (-1) or right (+1).
  func moveWidget(_ kind: String, by offset: Int) {
    guard let tab = selectedTab, let index = tab.widgets.firstIndex(of: kind) else { return }
    let target = index + offset
    guard tab.widgets.indices.contains(target) else { return }
    layoutStore.moveWidgets(
      in: tab.id, from: IndexSet(integer: index), to: offset > 0 ? target + 1 : target)
  }

  /// Width of the expanded panel for the open tab, up to the theme's width: a tab is as wide
  /// as its widgets, a single widget gets room for its detailed view, and the gallery, the
  /// editor and permission requests use the full width.
  func preferredPanelWidth(maxWidth: CGFloat) -> CGFloat {
    let padding: CGFloat = 56
    let spacing: CGFloat = 10
    let units = WidgetLayout.unitsPerTab
    guard !isShowingGallery, !isEditing, permissionBanner == nil, let tab = selectedTab else {
      return maxWidth
    }
    let unitWidth = (maxWidth - padding - spacing * CGFloat(units - 1)) / CGFloat(units)
    let kinds = tab.widgets.filter { registry.info(for: $0) != nil }
    let used = kinds.compactMap { registry.info(for: $0)?.size.units }.reduce(0, +)
    let shown = kinds.count > 1 ? used : max(used, 4)
    let width =
      padding + unitWidth * CGFloat(shown) + spacing * CGFloat(max(kinds.count - 1, shown - 1))
    return min(max(width, 360), maxWidth)
  }

  /// Size units still free in the open tab.
  var freeUnits: Int {
    let used = (selectedTab?.widgets ?? []).compactMap { registry.info(for: $0)?.size.units }
    return max(0, WidgetLayout.unitsPerTab - used.reduce(0, +))
  }

  /// Widgets that aren't in the open tab yet; they may be in other tabs.
  var addableInfos: [WidgetInfo] {
    let here = Set(selectedTab?.widgets ?? [])
    return registry.infos.filter { !here.contains($0.kind) }
  }

  /// Takes a widget out of the open tab; the gallery can add it back.
  func remove(_ kind: String) {
    guard let tab = selectedTab else { return }
    layoutStore.remove(kind, from: tab.id)
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

/// Tab buttons, then "+" to add a widget to the open tab and a button to edit it.
struct WidgetTabBar: View {
  let host: WidgetHost

  var body: some View {
    HStack(spacing: 4) {
      if host.tabs.count > 1 {
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
        Rectangle()
          .fill(.white.opacity(0.15))
          .frame(width: 1, height: 16)
          .padding(.horizontal, 4)
      }
      Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
          host.showGallery(!host.isShowingGallery)
        }
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(PanelButtonStyle(size: 24, isSelected: host.isShowingGallery))
      .help(Text("Add Widget"))
      .accessibilityLabel(Text("Add Widget"))
      Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
          host.setEditing(!host.isEditing)
        }
      } label: {
        Image(systemName: "slider.horizontal.3")
      }
      .buttonStyle(PanelButtonStyle(size: 24, isSelected: host.isEditing))
      .help(Text("Edit Tab"))
      .accessibilityLabel(Text("Edit Tab"))
    }
  }
}

/// The widgets of the selected tab side by side, sized by their units. An empty tab offers
/// to add one.
struct WidgetRow: View {
  let host: WidgetHost
  let secondary: Color

  var body: some View {
    let kinds = (host.selectedTab?.widgets ?? []).filter { host.registry.widget($0) != nil }
    if kinds.isEmpty {
      EmptyTabView(secondary: secondary) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
          host.showGallery(true)
        }
      }
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
                .environment(\.showsDetailedWidget, kinds.count == 1)
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
  /// Opens the panel, for a notification without an action that can run.
  var openPanel: () -> Void = {}

  var body: some View {
    VStack(spacing: 0) {
      row
        .frame(height: height)
        .accessibilityElement(children: .combine)
      if let notification = activity.notification {
        NotificationCard(notification: notification, openPanel: openPanel)
          .frame(height: NotchLayout.notificationHeight, alignment: .top)
          .transition(.opacity)
      }
    }
    .panelFont(.caption)
    .environment(\.peekHeight, height)
    // Beside the notch there is no room to grow, so the text size setting doesn't apply.
    .environment(\.panelTextScale, 1)
  }

  private var row: some View {
    HStack(spacing: 0) {
      // Clipped to the side, so nothing can slide under the camera housing where it can't
      // be seen; the full height keeps strokes and glyph edges whole.
      activity.leading
        .frame(width: sideWidth, height: height)
        .clipped()
      Color.clear
        .frame(width: notchWidth)
      activity.trailing
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: sideWidth, height: height)
        .clipped()
    }
  }
}

extension EnvironmentValues {
  /// Height of the closed notch, so live activities can size their content to it.
  @Entry var peekHeight: CGFloat = 32
  /// The widget is alone in its tab and has room for its detailed view; with others it
  /// shows a compact summary.
  @Entry var showsDetailedWidget = false
}
