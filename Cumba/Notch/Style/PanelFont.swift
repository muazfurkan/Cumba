import AppKit
import SwiftUI

extension EnvironmentValues {
  /// The theme's text size for the panel. macOS ignores Dynamic Type, so panel text sets
  /// its size through `panelFont` instead of plain text styles.
  @Entry var panelTextScale: CGFloat = 1
}

extension View {
  /// A text style at the panel's text size.
  func panelFont(
    _ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design? = nil,
    monospacedDigit: Bool = false
  ) -> some View {
    modifier(
      PanelFont(
        size: PanelFont.pointSize(of: style), weight: weight ?? PanelFont.weight(of: style),
        design: design, monospacedDigit: monospacedDigit))
  }

  /// A fixed size, scaled with the panel's text size.
  func panelFont(
    size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil,
    monospacedDigit: Bool = false
  ) -> some View {
    modifier(
      PanelFont(size: size, weight: weight, design: design, monospacedDigit: monospacedDigit))
  }
}

struct PanelFont: ViewModifier {
  let size: CGFloat
  let weight: Font.Weight
  let design: Font.Design?
  let monospacedDigit: Bool
  @Environment(\.panelTextScale) private var scale

  func body(content: Content) -> some View {
    let font = Font.system(size: (size * scale).rounded(), weight: weight, design: design)
    content.font(monospacedDigit ? font.monospacedDigit() : font)
  }

  /// The macOS size of a text style (caption is 10 pt, body 13 pt).
  static func pointSize(of style: Font.TextStyle) -> CGFloat {
    let nsStyle: NSFont.TextStyle =
      switch style {
      case .largeTitle: .largeTitle
      case .title: .title1
      case .title2: .title2
      case .title3: .title3
      case .headline: .headline
      case .subheadline: .subheadline
      case .callout: .callout
      case .footnote: .footnote
      case .caption: .caption1
      case .caption2: .caption2
      default: .body
      }
    return NSFont.preferredFont(forTextStyle: nsStyle).pointSize
  }

  static func weight(of style: Font.TextStyle) -> Font.Weight {
    style == .headline ? .semibold : .regular
  }
}
