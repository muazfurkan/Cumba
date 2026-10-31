import SwiftUI

/// Icon button used across the panel: a soft highlight on hover and a small spring press,
/// so every control answers the pointer.
struct PanelButtonStyle: ButtonStyle {
  var size: CGFloat = 26
  var isSelected = false

  func makeBody(configuration: Configuration) -> some View {
    PanelButtonBody(configuration: configuration, size: size, isSelected: isSelected)
  }
}

private struct PanelButtonBody: View {
  let configuration: ButtonStyle.Configuration
  let size: CGFloat
  let isSelected: Bool
  @State private var isHovered = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    configuration.label
      .frame(minWidth: size, minHeight: size * 0.85)
      .background {
        Capsule(style: .continuous)
          .fill(.white.opacity(backgroundOpacity))
      }
      .contentShape(Capsule(style: .continuous))
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .opacity(isEnabled ? 1 : 0.4)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .onHover { isHovered = $0 }
  }

  private var backgroundOpacity: Double {
    if configuration.isPressed { return 0.24 }
    if isSelected { return 0.18 }
    return isHovered ? 0.12 : 0
  }
}

/// Content that materializes: fades in from a slight blur and scale, the way the panel's
/// widgets appear after the shape opens.
struct MaterializeModifier: ViewModifier {
  let progress: Double

  func body(content: Content) -> some View {
    content
      .opacity(progress)
      .blur(radius: (1 - progress) * 8)
      .scaleEffect(0.96 + 0.04 * progress, anchor: .top)
  }
}

extension AnyTransition {
  static var materialize: AnyTransition {
    .modifier(
      active: MaterializeModifier(progress: 0), identity: MaterializeModifier(progress: 1))
  }
}

/// Hairline that gives the dark panel an edge against dark wallpapers; it fades out
/// towards the top so it never draws a line along the screen edge.
struct PanelEdge: View {
  let shape: NotchShape

  var body: some View {
    shape
      .stroke(
        LinearGradient(
          colors: [.white.opacity(0), .white.opacity(0.10)],
          startPoint: .top, endPoint: .bottom),
        lineWidth: 1
      )
      .allowsHitTesting(false)
  }
}
