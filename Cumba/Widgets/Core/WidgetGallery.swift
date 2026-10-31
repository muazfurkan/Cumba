import SwiftUI

/// Empty room in a tab: a dashed tile that opens the widget gallery right in the panel.
struct AddWidgetTile: View {
  /// The whole tab is empty, so the tile says what it does.
  let fillsTab: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: "plus")
          .font(.system(size: fillsTab ? 20 : 15, weight: .semibold))
        if fillsTab {
          Text("Add Widget")
            .panelFont(.callout)
        }
      }
      .foregroundStyle(.white.opacity(isHovered ? 0.85 : 0.5))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
          .foregroundStyle(.white.opacity(isHovered ? 0.4 : 0.2))
      }
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .animation(.easeOut(duration: 0.15), value: isHovered)
    .help(Text("Add Widget"))
    .accessibilityLabel(Text("Add Widget"))
  }
}

/// Every widget that isn't in the panel yet, to add to the open tab with one click.
struct WidgetGallery: View {
  let host: WidgetHost
  let secondary: Color

  var body: some View {
    let infos = host.addableInfos
    if infos.isEmpty {
      Text("Every widget is already in the panel.")
        .foregroundStyle(secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: 10) {
          ForEach(infos) { info in
            GalleryCard(info: info, fits: info.size.units <= host.freeUnits, secondary: secondary) {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                host.add(info.kind)
              }
            }
          }
        }
      }
      .scrollIndicators(.never)
    }
  }
}

private struct GalleryCard: View {
  let info: WidgetInfo
  /// There is room for it in the open tab.
  let fits: Bool
  let secondary: Color
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Image(systemName: info.symbol)
            .panelFont(.title3)
          Spacer()
          if fits {
            Image(systemName: "plus.circle.fill")
              .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.4))
          }
        }
        Text(info.title)
          .panelFont(.callout, weight: .semibold)
          .lineLimit(1)
        Text(fits ? info.summary : String(localized: "No room in this tab"))
          .panelFont(.caption)
          .foregroundStyle(secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .padding(10)
      .frame(width: 150, alignment: .topLeading)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(
        .white.opacity(isHovered && fits ? 0.14 : 0.07),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
      )
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .opacity(fits ? 1 : 0.5)
    }
    .buttonStyle(.plain)
    .disabled(!fits)
    .onHover { isHovered = $0 }
    .animation(.easeOut(duration: 0.15), value: isHovered)
    .accessibilityLabel(Text(info.title))
    .accessibilityHint(fits ? Text(info.summary) : Text("No room in this tab"))
  }
}
