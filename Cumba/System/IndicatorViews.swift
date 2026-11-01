import SwiftUI

extension EnvironmentValues {
  /// Colors of the volume and brightness levels beside the notch, from the theme.
  @Entry var indicatorColors: [Color] = [.white]
}

extension Theme {
  /// The chosen indicator color, or the theme's own: its neon edge fading into the accent,
  /// or just the accent.
  var indicatorColors: [Color] {
    switch indicatorColor {
    case .theme: glow.map { [$0.color, accent.color] } ?? [accent.color]
    case .white: [.white]
    case .blue: [.blue]
    case .green: [.green]
    case .orange: [.orange]
    case .pink: [.pink]
    case .purple: [.purple]
    }
  }
}

/// A volume or brightness symbol beside the closed notch, as large as the notch allows, in
/// the theme's indicator color.
struct LevelSymbol: View {
  let name: String
  let label: Text
  @Environment(\.peekHeight) private var height
  @Environment(\.indicatorColors) private var colors

  var body: some View {
    Image(systemName: name)
      .font(.system(size: max(14, height * 0.46), weight: .semibold))
      .foregroundStyle(
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .contentTransition(.symbolEffect(.replace))
      .accessibilityLabel(label)
  }
}

/// A volume or brightness level as a bar beside the closed notch, filled in the theme's
/// indicator color.
struct LevelBar: View {
  let level: Float
  let label: Text
  @Environment(\.indicatorColors) private var colors

  var body: some View {
    let fraction = CGFloat(min(max(level, 0), 1))
    GeometryReader { proxy in
      Capsule()
        .fill(.white.opacity(0.18))
        .overlay(alignment: .leading) {
          Capsule()
            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(width: fraction > 0 ? max(proxy.size.width * fraction, 7) : 0)
        }
    }
    .frame(height: 7)
    .padding(.leading, 8)
    .padding(.trailing, 14)
    .animation(.easeOut(duration: 0.12), value: level)
    .accessibilityElement()
    .accessibilityLabel(label)
    .accessibilityValue(Text(Double(level), format: .percent.precision(.fractionLength(0))))
  }
}

/// A low battery beside the closed notch: a red ring on one side and the percentage on the
/// other, like the battery widget's ring.
struct LowBatteryRing: View {
  let percent: Int
  @Environment(\.peekHeight) private var height

  var body: some View {
    let size = max(16, height * 0.6)
    let fraction = CGFloat(min(max(percent, 0), 100)) / 100
    Circle()
      .inset(by: 2)
      .stroke(Color.red.opacity(0.25), lineWidth: 4)
      .overlay {
        Circle()
          .inset(by: 2)
          .trim(from: 0, to: fraction)
          .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .rotationEffect(.degrees(-90))
      }
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

struct LowBatteryPercent: View {
  let percent: Int
  @Environment(\.peekHeight) private var height

  var body: some View {
    Text(Double(percent) / 100, format: .percent)
      .font(.system(size: max(12, height * 0.4), weight: .bold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(.red)
      .contentTransition(.numericText())
      .accessibilityLabel(Text("Low battery"))
      .accessibilityValue(Text(Double(percent) / 100, format: .percent))
  }
}
