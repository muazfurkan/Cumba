import SwiftUI

/// Form sections that edit every field of a theme.
struct ThemeEditorSections: View {
  @Binding var theme: Theme

  var body: some View {
    Section("Material") {
      Picker("Material", selection: $theme.material) {
        Text("Liquid Glass").tag(Theme.Material.glass)
        Text("Solid black").tag(Theme.Material.solid)
        Text("Tinted glass").tag(Theme.Material.tinted)
      }
      .pickerStyle(.segmented)
      if theme.material == .tinted {
        ColorPicker("Tint", selection: color(\.tint), supportsOpacity: false)
      }
      if theme.material == .solid {
        ColorPicker("Background", selection: color(\.background), supportsOpacity: false)
        Toggle("Gradient", isOn: optional(\.gradient, default: gradientStart))
        if theme.gradient != nil {
          ColorPicker("Bottom color", selection: color(\.gradient), supportsOpacity: false)
        }
      }
    }

    Section("Colors") {
      ColorPicker("Text", selection: color(\.foreground), supportsOpacity: false)
      ColorPicker("Secondary text", selection: color(\.secondary), supportsOpacity: false)
      ColorPicker("Accent", selection: color(\.accent), supportsOpacity: false)
      Toggle("Neon edge", isOn: optional(\.glow, default: theme.accent))
      if theme.glow != nil {
        ColorPicker("Edge color", selection: color(\.glow), supportsOpacity: false)
          .help(Text("The edge fades from this color into the accent."))
      }
      Picker("Font", selection: $theme.fontDesign) {
        Text("Default").tag(Theme.FontDesign.default)
        Text("Rounded").tag(Theme.FontDesign.rounded)
        Text("Monospaced").tag(Theme.FontDesign.monospaced)
        Text("Serif").tag(Theme.FontDesign.serif)
      }
      ValueSlider(
        title: "Text size", value: $theme.textScale, range: Theme.textScaleRange,
        fractionDigits: 2)
    }

    Section("Size") {
      ValueSlider(title: "Width", value: $theme.expandedSize.width, range: Theme.widthRange)
      ValueSlider(title: "Height", value: $theme.expandedSize.height, range: Theme.heightRange)
      ValueSlider(
        title: "Corner radius", value: $theme.cornerRadius, range: Theme.cornerRadiusRange)
      ValueSlider(
        title: "Indicator width", value: $theme.peekExtraWidth, range: Theme.peekWidthRange)
      Toggle("Shadow", isOn: $theme.shadow)
    }

    Section("Animation") {
      ValueSlider(
        title: "Duration", value: $theme.spring.response, range: Theme.responseRange,
        fractionDigits: 2)
      ValueSlider(
        title: "Bounce", value: bounce, range: 0...(1 - Theme.dampingRange.lowerBound),
        fractionDigits: 2)
    }
  }

  private func color(_ keyPath: WritableKeyPath<Theme, HexColor>) -> Binding<Color> {
    Binding(
      get: { theme[keyPath: keyPath].color },
      set: { theme[keyPath: keyPath] = HexColor($0) })
  }

  private func color(_ keyPath: WritableKeyPath<Theme, HexColor?>) -> Binding<Color> {
    Binding(
      get: { (theme[keyPath: keyPath] ?? theme.background).color },
      set: { theme[keyPath: keyPath] = HexColor($0) })
  }

  /// A first bottom color for a new gradient: the background with a hint of the accent.
  private var gradientStart: HexColor {
    HexColor(theme.background.color.mix(with: theme.accent.color, by: 0.3))
  }

  /// Turns an optional color on, starting from `default`, or off.
  private func optional(_ keyPath: WritableKeyPath<Theme, HexColor?>, default value: HexColor)
    -> Binding<Bool>
  {
    Binding(
      get: { theme[keyPath: keyPath] != nil },
      set: { theme[keyPath: keyPath] = $0 ? value : nil })
  }

  /// Damping shown the other way round: 0 means no bounce.
  private var bounce: Binding<Double> {
    Binding(
      get: { 1 - theme.spring.damping },
      set: { theme.spring.damping = 1 - $0 })
  }
}

/// Slider with its current value shown next to it.
private struct ValueSlider: View {
  let title: LocalizedStringKey
  @Binding var value: Double
  let range: ClosedRange<Double>
  var fractionDigits = 0

  var body: some View {
    LabeledContent(title) {
      HStack {
        Slider(value: $value, in: range)
        Text(value, format: .number.precision(.fractionLength(fractionDigits)))
          .monospacedDigit()
          .frame(width: 44, alignment: .trailing)
      }
    }
  }
}
