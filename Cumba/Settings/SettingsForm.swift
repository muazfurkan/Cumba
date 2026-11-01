import SwiftUI

/// A settings page: a large icon, its title and what it's for, then its grouped rows.
/// Toggles are switches on the right, as in System Settings.
struct SettingsForm<Content: View>: View {
  let info: SettingsPageInfo
  @ViewBuilder let content: Content

  var body: some View {
    Form {
      Section {
        PageHeader(info: info)
          // Above the groups, without a box of its own.
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
      content
    }
    .formStyle(.grouped)
    .toggleStyle(.switch)
  }
}

/// The top of a page: its icon, title and description, centered.
struct PageHeader: View {
  let info: SettingsPageInfo

  var body: some View {
    VStack(spacing: 8) {
      PageIcon(symbol: info.symbol, color: info.color, size: 56)
      Text(info.title)
        .font(.title2.weight(.bold))
      Text(info.summary)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
  }
}

/// A white symbol on a rounded square in the page's color, like System Settings.
struct PageIcon: View {
  let symbol: String
  let color: Color
  var size: CGFloat = 20

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
      .fill(color.gradient)
      .frame(width: size, height: size)
      .overlay {
        Image(systemName: symbol)
          .font(.system(size: size * 0.5, weight: .semibold))
          .foregroundStyle(.white)
      }
      .accessibilityHidden(true)
  }
}

/// A row's title with an ⓘ that explains it on hover.
struct InfoLabel: View {
  let title: LocalizedStringKey
  let help: LocalizedStringKey

  init(_ title: LocalizedStringKey, help: LocalizedStringKey) {
    self.title = title
    self.help = help
  }

  var body: some View {
    HStack(spacing: 5) {
      Text(title)
      Image(systemName: "info.circle")
        .foregroundStyle(.tertiary)
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }
  }
}
