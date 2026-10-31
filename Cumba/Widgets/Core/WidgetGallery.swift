import SwiftUI

/// An empty tab: a short note and a small button that opens the gallery.
struct EmptyTabView: View {
  let secondary: Color
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Text("This tab is empty.")
        .panelFont(.callout)
        .foregroundStyle(secondary)
      Button(action: action) {
        Label("Add Widget", systemImage: "plus")
          .panelFont(.callout, weight: .medium)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(.white.opacity(0.1), in: Capsule())
          .contentShape(Capsule())
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Every widget that isn't in the open tab yet, to add to it with one click.
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
