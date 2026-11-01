import SwiftUI

/// A widget's name above its content, like Apple's widgets: its symbol and name in the
/// widget's own color, with anything trailing in gray on the right.
struct WidgetHeader<Trailing: View>: View {
  let title: Text
  let symbol: String
  let color: Color
  @ViewBuilder let trailing: Trailing

  init(
    _ title: LocalizedStringKey, symbol: String, color: Color,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.title = Text(title)
    self.symbol = symbol
    self.color = color
    self.trailing = trailing()
  }

  /// A name that comes from the user's data, such as a list name, shown as written:
  /// Markdown in it doesn't become a link.
  init(
    verbatim title: String, symbol: String, color: Color,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.title = Text(verbatim: title)
    self.symbol = symbol
    self.color = color
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: symbol)
        .symbolVariant(.fill)
        .accessibilityHidden(true)
      title
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 4)
      trailing
        .foregroundStyle(Color.secondary)
    }
    .panelFont(.caption, weight: .semibold)
    .foregroundStyle(color)
    .lineLimit(1)
  }
}
