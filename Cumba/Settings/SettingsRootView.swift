import SwiftUI

/// Which page the Settings window shows, kept across openings.
@MainActor
@Observable
final class SettingsNavigation {
  var page: SettingsPage? {
    didSet { UserDefaults.standard.set(page?.id, forKey: Self.key) }
  }
  var search = ""

  private static let key = "settingsPage"

  init() {
    page =
      UserDefaults.standard.string(forKey: Self.key).flatMap(SettingsPage.init(id:)) ?? .general
  }
}

/// The Settings window: a searchable sidebar of pages in three groups, and the open page.
struct SettingsRootView: View {
  @Bindable var navigation: SettingsNavigation
  let settings: AppSettings
  let themes: ThemeStore
  let layoutStore: LayoutStore
  let registry: WidgetRegistry
  let server: LocalServer
  let updates: UpdateChecker
  let diagnostics: Diagnostics.Sources

  var body: some View {
    NavigationSplitView {
      List(selection: $navigation.page) {
        section(nil, pages: SettingsPage.main)
        section(
          String(localized: "Widgets", comment: "Settings sidebar group"),
          pages: [.widgets] + widgetPages)
        section(
          String(localized: "Features", comment: "Settings sidebar group"),
          pages: SettingsPage.features)
      }
      .searchable(
        text: $navigation.search, placement: .sidebar,
        prompt: Text("Search Settings", comment: "Settings sidebar search field")
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    } detail: {
      let page = navigation.page ?? .general
      detail(page)
        .id(page)
        .navigationTitle(page.info(registry: registry).title)
    }
  }

  /// Widgets in the panel that have settings of their own.
  private var widgetPages: [SettingsPage] {
    registry.infos
      .filter { registry.widget($0.kind)?.makeSettingsView() != nil }
      .map { .widget($0.kind) }
  }

  @ViewBuilder
  private func section(_ title: String?, pages: [SettingsPage]) -> some View {
    let shown = pages.filter(matchesSearch)
    if !shown.isEmpty {
      Section {
        ForEach(shown) { page in
          let info = page.info(registry: registry)
          Label {
            Text(verbatim: info.title)
          } icon: {
            PageIcon(symbol: info.symbol, color: info.color)
          }
          .tag(page)
        }
      } header: {
        if let title {
          Text(verbatim: title)
        }
      }
    }
  }

  private func matchesSearch(_ page: SettingsPage) -> Bool {
    let query = navigation.search.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return true }
    let info = page.info(registry: registry)
    return ([info.title, info.summary] + info.keywords).contains {
      $0.localizedCaseInsensitiveContains(query)
    }
  }

  @ViewBuilder
  private func detail(_ page: SettingsPage) -> some View {
    let info = page.info(registry: registry)
    switch page {
    case .general:
      GeneralSettingsView(
        info: info, settings: settings, updates: updates, diagnostics: diagnostics)
    case .appearance:
      AppearanceSettingsView(info: info, themes: themes, settings: settings)
    case .displays:
      DisplaysSettingsView(info: info, settings: settings)
    case .behavior:
      BehaviorSettingsView(info: info, settings: settings, layoutStore: layoutStore)
    case .indicators:
      IndicatorsSettingsView(info: info, settings: settings)
    case .permissions:
      PermissionsSettingsView(info: info)
    case .widgets:
      WidgetsSettingsView(info: info, layoutStore: layoutStore, registry: registry)
    case .widget(let kind):
      SettingsForm(info: info) {
        if let view = registry.widget(kind)?.makeSettingsView() {
          Section { view }
        } else {
          Text("Add this widget to the panel to change its settings.")
            .foregroundStyle(.secondary)
        }
      }
    case .agents:
      ClaudeCodeSettingsView(
        info: info, server: server, settings: settings,
        onHooksInstalled: { [layoutStore] in layoutStore.addAnywhere(ClaudeCodeWidget.kind) })
    case .connections:
      ConnectionsSettingsView(info: info, server: server, settings: settings)
    }
  }
}
