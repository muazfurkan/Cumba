import SwiftUI

/// Tabs of the panel and the widgets in them, the gallery of every widget, and per-widget
/// settings. Every widget can be added, removed and reordered.
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
        Section {
          if tab.widgets.isEmpty {
            Text("Add widgets from the gallery below.")
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
              remove: { layoutStore.remove(kind, from: tab.id) })
          }
          .onMove { source, destination in
            layoutStore.moveWidgets(in: tab.id, from: source, to: destination)
          }
        } header: {
          Text("Widgets in This Tab")
        } footer: {
          Text("Drag to reorder.")
        }
      }

      Section("Widget Gallery") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
          ForEach(registry.infos) { info in
            GalleryCard(
              info: info,
              tabTitle: tab.flatMap { $0.widgets.contains(info.kind) ? $0.title : nil },
              add: {
                if let tab {
                  layoutStore.add(info.kind, to: tab.id)
                }
              },
              remove: {
                if let tab {
                  layoutStore.remove(info.kind, from: tab.id)
                }
              })
          }
        }
        .padding(.vertical, 4)
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
    .frame(width: 520, height: 620)
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
      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
      Label(info?.title ?? kind, systemImage: info?.symbol ?? "questionmark.square")
      Spacer()
      Button(role: .destructive, action: remove) {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(Text("Remove"))
    }
    .contextMenu {
      Button("Move Up") { move(-1) }
        .disabled(!canMoveUp)
      Button("Move Down") { move(1) }
        .disabled(!canMoveDown)
      Button("Remove", role: .destructive, action: remove)
    }
    .accessibilityActions {
      if canMoveUp {
        Button("Move Up") { move(-1) }
      }
      if canMoveDown {
        Button("Move Down") { move(1) }
      }
    }
  }
}

/// A widget in the gallery: what it does, where it is, and one button to add or remove it.
private struct GalleryCard: View {
  let info: WidgetInfo
  /// The tab that shows it, or nil when it isn't in the panel.
  let tabTitle: String?
  let add: () -> Void
  let remove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        Image(systemName: info.symbol)
          .font(.title3)
          .foregroundStyle(.tint)
          .frame(width: 30, height: 30)
          .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
          .accessibilityHidden(true)
        Spacer()
        if let tabTitle {
          Text(verbatim: tabTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
        }
      }
      Text(info.title)
        .font(.headline)
      Text(info.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2, reservesSpace: true)
      if tabTitle == nil {
        Button("Add", action: add)
      } else {
        Button("Remove", role: .destructive, action: remove)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .contain)
  }
}
