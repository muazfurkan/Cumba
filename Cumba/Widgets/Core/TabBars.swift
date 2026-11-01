import SwiftUI

extension AppSettings.TabBarStyle {
  var title: String {
    switch self {
    case .compact: String(localized: "Compact", comment: "Tab bar style")
    case .icons: String(localized: "Symbols", comment: "Tab bar style")
    case .inPanel: String(localized: "In the Panel", comment: "Tab bar style")
    case .top: String(localized: "At the Top", comment: "Tab bar style")
    case .dots: String(localized: "Dots", comment: "Tab bar style")
    }
  }
}

/// Tab buttons inside the panel, then "+" to add a widget to the open tab and a button to
/// edit it.
struct WidgetTabBar: View {
  let host: WidgetHost

  var body: some View {
    HStack(spacing: 4) {
      if host.tabs.count > 1 {
        ForEach(host.tabs) { tab in
          let isSelected = tab.id == host.selectedTab?.id
          Button {
            host.slide(to: tab.id)
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
      TabActions(host: host)
    }
  }
}

/// "+" to add a widget to the open tab and a button to edit it.
struct TabActions: View {
  let host: WidgetHost

  var body: some View {
    HStack(spacing: 4) {
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

/// The tabs as a bar of their own under the open panel: the open tab with its name
/// (compact), symbols with a dot under the open one, or just dots.
struct FloatingTabBar: View {
  let host: WidgetHost
  let style: AppSettings.TabBarStyle
  let theme: Theme
  @Namespace private var selection

  var body: some View {
    HStack(spacing: 2) {
      ForEach(host.tabs) { tab in
        let isSelected = tab.id == host.selectedTab?.id
        Button {
          host.slide(to: tab.id)
        } label: {
          item(tab, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .padding(.horizontal, style == .dots ? 8 : 4)
    .frame(height: style == .dots ? 22 : 34)
    .background { TabBarBackground(theme: theme) }
    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: host.selectedTab?.id)
  }

  @ViewBuilder private func item(_ tab: WidgetLayout.Tab, isSelected: Bool) -> some View {
    switch style {
    case .compact:
      HStack(spacing: 5) {
        Image(systemName: tab.symbol)
          .symbolVariant(isSelected ? .fill : .none)
        if isSelected {
          Text(tab.title)
            .lineLimit(1)
            .fixedSize()
        }
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(isSelected ? .primary : .secondary)
      .padding(.horizontal, isSelected ? 11 : 8)
      .frame(height: 26)
      .background {
        if isSelected {
          Capsule()
            .fill(.white.opacity(0.16))
            .matchedGeometryEffect(id: "selection", in: selection)
        }
      }
      .contentShape(Capsule())
    case .icons:
      VStack(spacing: 2) {
        Image(systemName: tab.symbol)
          .symbolVariant(isSelected ? .fill : .none)
          .font(.system(size: 13, weight: .semibold))
        Circle()
          .fill(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.clear))
          .frame(width: 4, height: 4)
      }
      .foregroundStyle(isSelected ? .primary : .secondary)
      .frame(width: 32, height: 30)
      .contentShape(Rectangle())
    case .dots, .inPanel, .top:
      Capsule()
        .fill(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.6)))
        .frame(width: isSelected ? 18 : 6, height: 6)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }
  }
}

/// The bar's capsule in the theme's material, like the panel.
private struct TabBarBackground: View {
  let theme: Theme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    Group {
      switch theme.material {
      case .glass where !reduceTransparency:
        Color.clear.glassEffect(.regular, in: Capsule())
      case .tinted where !reduceTransparency:
        Color.clear.glassEffect(.regular.tint(theme.tint.color), in: Capsule())
      default:
        Capsule().fill(theme.background.color)
      }
    }
    .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
  }
}
