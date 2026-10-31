import SwiftUI

/// Tabs of the panel and the widgets in them, plus per-widget settings.
struct WidgetsSettingsView: View {
  let layoutStore: LayoutStore
  let registry: WidgetRegistry
  @State private var selectedTabID: String?

  private var tabs: [WidgetLayout.Tab] { layoutStore.layout.tabs }
  private var tab: WidgetLayout.Tab? {
    tabs.first { $0.id == selectedTabID } ?? tabs.first
  }

  var body: some View {
    Form {
      Section("Tabs") {
        Picker("Tab", selection: tabSelection) {
          ForEach(tabs) { tab in
            Label(tab.title, systemImage: tab.symbol).tag(tab.id)
          }
        }
        HStack {
          Button("Add Tab") {
            selectedTabID = layoutStore.addTab(
              title: String(localized: "New Tab", comment: "Default name of a new panel tab"))
          }
          Button("Remove Tab", role: .destructive) {
            if let tab {
              layoutStore.removeTab(tab.id)
              selectedTabID = nil
            }
          }
          .disabled(tabs.count <= 1)
        }
        if let tab {
          TextField("Name", text: tabTitle(tab))
          Picker("Symbol", selection: tabSymbol(tab)) {
            ForEach(WidgetLayout.tabSymbols, id: \.self) { symbol in
              Image(systemName: symbol).tag(symbol)
            }
          }
        }
      }

      if let tab {
        Section("Widgets in This Tab") {
          if tab.widgets.isEmpty {
            Text("No widgets yet.")
              .foregroundStyle(.secondary)
          }
          ForEach(Array(tab.widgets.enumerated()), id: \.element) { index, kind in
            WidgetRowEditor(
              kind: kind, info: registry.info(for: kind),
              canMoveUp: index > 0, canMoveDown: index < tab.widgets.count - 1,
              move: { offset in
                layoutStore.moveWidgets(
                  in: tab.id, from: IndexSet(integer: index),
                  to: offset < 0 ? index - 1 : index + 2)
              },
              remove: { layoutStore.remove(kind) })
          }
          let available = registry.infos.filter { !layoutStore.layout.contains($0.kind) }
          if !available.isEmpty {
            Menu("Add Widget") {
              ForEach(available) { info in
                Button {
                  layoutStore.add(info.kind, to: tab.id)
                } label: {
                  Label(info.title, systemImage: info.symbol)
                }
              }
            }
          }
        }
      }

      ForEach(registry.infos) { info in
        if let settingsView = registry.widget(info.kind)?.makeSettingsView() {
          Section(info.title) {
            settingsView
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 560)
  }

  private var tabSelection: Binding<String> {
    Binding(get: { tab?.id ?? "" }, set: { selectedTabID = $0 })
  }

  private func tabTitle(_ tab: WidgetLayout.Tab) -> Binding<String> {
    Binding(get: { tab.title }, set: { layoutStore.updateTab(tab.id, title: $0) })
  }

  private func tabSymbol(_ tab: WidgetLayout.Tab) -> Binding<String> {
    Binding(get: { tab.symbol }, set: { layoutStore.updateTab(tab.id, symbol: $0) })
  }
}

private struct WidgetRowEditor: View {
  let kind: String
  let info: WidgetInfo?
  let canMoveUp: Bool
  let canMoveDown: Bool
  let move: (Int) -> Void
  let remove: () -> Void

  var body: some View {
    HStack {
      Label(info?.title ?? kind, systemImage: info?.symbol ?? "questionmark.square")
      Spacer()
      Button {
        move(-1)
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(!canMoveUp)
      .accessibilityLabel(Text("Move Up"))
      Button {
        move(1)
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(!canMoveDown)
      .accessibilityLabel(Text("Move Down"))
      Button(role: .destructive, action: remove) {
        Image(systemName: "minus.circle")
      }
      .accessibilityLabel(Text("Remove"))
    }
    .buttonStyle(.borderless)
  }
}
