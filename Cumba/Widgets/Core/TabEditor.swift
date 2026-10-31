import SwiftUI

/// Edits the open tab right in the panel: its name and symbol, where it sits among the tabs,
/// and the order of its widgets. New tabs start here too.
struct TabEditor: View {
  let host: WidgetHost
  let secondary: Color

  var body: some View {
    if let tab = host.selectedTab {
      HStack(alignment: .top, spacing: 16) {
        TabDetails(host: host, tab: tab, secondary: secondary)
          .frame(width: 236)
        Rectangle()
          .fill(.white.opacity(0.12))
          .frame(width: 1)
        TabWidgets(host: host, tab: tab, secondary: secondary)
      }
    }
  }
}

private struct TabDetails: View {
  let host: WidgetHost
  let tab: WidgetLayout.Tab
  let secondary: Color

  private let columns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 7)

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField(
        "Tab name",
        text: Binding(
          get: { tab.title }, set: { host.layoutStore.updateTab(tab.id, title: $0) })
      )
      .textFieldStyle(.plain)
      .panelFont(.callout)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
        ForEach(WidgetLayout.tabSymbols, id: \.self) { symbol in
          Button {
            host.layoutStore.updateTab(tab.id, symbol: symbol)
          } label: {
            Image(systemName: symbol)
          }
          .buttonStyle(PanelButtonStyle(size: 28, isSelected: symbol == tab.symbol))
          .accessibilityLabel(Text(symbol))
        }
      }
      HStack(spacing: 4) {
        Button {
          host.moveSelectedTab(by: -1)
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(PanelButtonStyle(size: 24))
        .disabled(host.tabs.first?.id == tab.id)
        .help(Text("Move Left"))
        .accessibilityLabel(Text("Move Left"))
        Button {
          host.moveSelectedTab(by: 1)
        } label: {
          Image(systemName: "chevron.right")
        }
        .buttonStyle(PanelButtonStyle(size: 24))
        .disabled(host.tabs.last?.id == tab.id)
        .help(Text("Move Right"))
        .accessibilityLabel(Text("Move Right"))
        Spacer(minLength: 4)
        Button("New Tab") {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { host.addTab() }
        }
        .buttonStyle(.plain)
        .panelFont(.caption, weight: .medium)
        Button("Delete Tab", role: .destructive) {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            host.deleteSelectedTab()
          }
        }
        .buttonStyle(.plain)
        .panelFont(.caption, weight: .medium)
        .foregroundStyle(host.tabs.count > 1 ? .red : secondary)
        .disabled(host.tabs.count < 2)
      }
    }
  }
}

private struct TabWidgets: View {
  let host: WidgetHost
  let tab: WidgetLayout.Tab
  let secondary: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Widgets in This Tab")
        .panelFont(.caption)
        .foregroundStyle(secondary)
      if tab.widgets.isEmpty {
        Text("None yet. Use + to add one.")
          .panelFont(.callout)
          .foregroundStyle(secondary)
      } else {
        ScrollView {
          VStack(spacing: 4) {
            ForEach(Array(tab.widgets.enumerated()), id: \.element) { index, kind in
              if let info = host.registry.info(for: kind) {
                WidgetLine(
                  info: info, isFirst: index == 0, isLast: index == tab.widgets.count - 1,
                  move: { offset in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                      host.moveWidget(kind, by: offset)
                    }
                  },
                  remove: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                      host.remove(kind)
                    }
                  })
              }
            }
          }
        }
        .scrollIndicators(.never)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct WidgetLine: View {
  let info: WidgetInfo
  let isFirst: Bool
  let isLast: Bool
  let move: (Int) -> Void
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: info.symbol)
        .frame(width: 18)
        .accessibilityHidden(true)
      Text(info.title)
        .panelFont(.callout)
        .lineLimit(1)
      Spacer(minLength: 4)
      Button {
        move(-1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(PanelButtonStyle(size: 22))
      .disabled(isFirst)
      .help(Text("Move Left"))
      .accessibilityLabel(Text("Move Left"))
      Button {
        move(1)
      } label: {
        Image(systemName: "chevron.right")
      }
      .buttonStyle(PanelButtonStyle(size: 22))
      .disabled(isLast)
      .help(Text("Move Right"))
      .accessibilityLabel(Text("Move Right"))
      Button(action: remove) {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(.red)
      }
      .buttonStyle(PanelButtonStyle(size: 22))
      .help(Text("Remove \(info.title)"))
      .accessibilityLabel(Text("Remove \(info.title)"))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}
