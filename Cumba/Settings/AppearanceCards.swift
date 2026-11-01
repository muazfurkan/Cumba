import SwiftUI

/// A card to pick: a small picture above its name, outlined in the accent color when chosen.
struct ChoiceCard<Preview: View>: View {
  let title: String
  let isSelected: Bool
  let select: () -> Void
  @ViewBuilder let preview: Preview

  var body: some View {
    Button(action: select) {
      VStack(spacing: 6) {
        preview
          .frame(height: 70)
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(
                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                lineWidth: isSelected ? 2.5 : 1)
          }
        Text(verbatim: title)
          .font(.callout.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .primary : .secondary)
          .lineLimit(1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: title))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

/// A desktop with the panel open in the theme's look: its fill, edge, accent and text colors.
struct ThemePreview: View {
  let theme: Theme

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width * 0.74
      let height = proxy.size.height * 0.62
      let shape = UnevenRoundedRectangle(
        bottomLeadingRadius: min(theme.cornerRadius / 3, 12),
        bottomTrailingRadius: min(theme.cornerRadius / 3, 12), style: .continuous)
      ZStack(alignment: .top) {
        Wallpaper()
        shape
          .fill(fill)
          .overlay {
            if let glow = theme.glow {
              shape.stroke(
                LinearGradient(
                  colors: [glow.color, theme.accent.color], startPoint: .leading,
                  endPoint: .trailing), lineWidth: 1.5)
            }
          }
          .overlay(alignment: .topLeading) {
            HStack(spacing: 5) {
              RoundedRectangle(cornerRadius: 3)
                .fill(theme.accent.color)
                .frame(width: height * 0.36, height: height * 0.36)
              VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(theme.foreground.color).frame(width: width * 0.36, height: 3)
                Capsule().fill(theme.secondary.color).frame(width: width * 0.24, height: 3)
              }
            }
            .padding(.top, height * 0.38)
            .padding(.leading, width * 0.1)
          }
          .frame(width: width, height: height)
          .shadow(color: .black.opacity(theme.shadow ? 0.35 : 0), radius: 4, y: 2)
      }
    }
  }

  private var fill: AnyShapeStyle {
    switch theme.material {
    case .solid:
      AnyShapeStyle(
        LinearGradient(
          colors: [theme.background.color, (theme.gradient ?? theme.background).color],
          startPoint: .top, endPoint: .bottom))
    case .glass:
      AnyShapeStyle(Color.white.opacity(0.22))
    case .tinted:
      AnyShapeStyle(theme.tint.color.opacity(0.55))
    }
  }
}

/// A desktop with the open panel and its tabs in one of the tab bar styles.
struct TabStylePreview: View {
  let style: AppSettings.TabBarStyle

  var body: some View {
    GeometryReader { proxy in
      let panelWidth = proxy.size.width * 0.62
      let panelHeight = proxy.size.height * 0.48
      ZStack(alignment: .top) {
        LinearGradient(
          colors: [
            Color(red: 0.36, green: 0.3, blue: 0.75), Color(red: 0.27, green: 0.22, blue: 0.6),
          ],
          startPoint: .top, endPoint: .bottom)
        VStack(spacing: 4) {
          UnevenRoundedRectangle(
            bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous
          )
          .fill(.black)
          .frame(width: panelWidth, height: panelHeight)
          .overlay(alignment: style == .top ? .topLeading : .bottom) {
            if style == .inPanel || style == .top {
              symbols(count: 4, size: 4.5)
                .padding(.bottom, style == .inPanel ? 5 : 0)
                .padding(.top, style == .top ? 5 : 0)
                .padding(.leading, style == .top ? 8 : 0)
            }
          }
          if style.isFloating {
            floatingBar
          }
        }
      }
    }
  }

  @ViewBuilder private var floatingBar: some View {
    Group {
      switch style {
      case .compact:
        HStack(spacing: 4) {
          HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 5, height: 5)
            Capsule().fill(.white).frame(width: 10, height: 3)
          }
          .padding(.horizontal, 4)
          .padding(.vertical, 2.5)
          .background(.white.opacity(0.22), in: Capsule())
          symbols(count: 3, size: 4.5)
        }
      case .icons:
        HStack(spacing: 5) {
          ForEach(0..<4, id: \.self) { index in
            VStack(spacing: 1.5) {
              RoundedRectangle(cornerRadius: 1).fill(.white.opacity(index == 0 ? 1 : 0.6))
                .frame(width: 5, height: 5)
              Circle().fill(.white.opacity(index == 0 ? 1 : 0)).frame(width: 1.5, height: 1.5)
            }
          }
        }
      default:
        HStack(spacing: 3) {
          Capsule().fill(.white).frame(width: 9, height: 3)
          ForEach(0..<3, id: \.self) { _ in
            Circle().fill(.white.opacity(0.5)).frame(width: 3, height: 3)
          }
        }
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3.5)
    .background(.black, in: Capsule())
  }

  private func symbols(count: Int, size: CGFloat) -> some View {
    HStack(spacing: size) {
      ForEach(0..<count, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1)
          .fill(.white.opacity(index == 0 ? 1 : 0.6))
          .frame(width: size, height: size)
      }
    }
  }
}

/// The open panel with three widgets, set apart by faint lines or on cards of their own.
struct WidgetStylePreview: View {
  let style: AppSettings.WidgetStyle

  var body: some View {
    GeometryReader { proxy in
      let panel = CGSize(width: proxy.size.width * 0.82, height: proxy.size.height * 0.7)
      ZStack(alignment: .top) {
        Wallpaper()
        UnevenRoundedRectangle(
          bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous
        )
        .fill(.black)
        .frame(width: panel.width, height: panel.height)
        .overlay {
          HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
              VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(.white.opacity(0.85)).frame(width: 16, height: 3)
                Capsule().fill(.white.opacity(0.4)).frame(width: 22, height: 3)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
              .padding(5)
              .background {
                if style == .cards {
                  RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(0.13))
                }
              }
              .overlay(alignment: .leading) {
                if style == .lines, index > 0 {
                  Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
                    .padding(.vertical, 6).offset(x: -3.5)
                }
              }
            }
          }
          .padding(.horizontal, 8)
          .padding(.top, 12)
          .padding(.bottom, 6)
        }
      }
    }
  }
}

/// A calm desktop behind the previews.
private struct Wallpaper: View {
  var body: some View {
    LinearGradient(
      colors: [
        Color(red: 0.42, green: 0.55, blue: 0.85), Color(red: 0.86, green: 0.6, blue: 0.68),
      ],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}
