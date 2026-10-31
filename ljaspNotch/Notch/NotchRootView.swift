import AppKit
import SwiftUI

/// Root of the notch panel. The window has a fixed size; only the shape inside it grows
/// and shrinks. Content is laid out once at full size and revealed by the growing shape,
/// so nothing reflows while the panel animates.
struct NotchRootView: View {
  let model: NotchViewModel
  let host: WidgetHost

  var body: some View {
    if let geometry = model.geometry {
      let state = model.state
      let theme = model.theme
      let size = geometry.shapeSize(for: state)
      let canvas = geometry.shapeSize(for: .expanded)
      let shape = NotchShape(
        topRadius: state.isOpen ? 14 : 6, bottomRadius: state.isOpen ? theme.cornerRadius : 10)
      // Over the hardware notch the closed shape is plain black so it blends in.
      let material = state == .closed && !geometry.isVirtual ? .solid : theme.material

      ZStack(alignment: .top) {
        if state.isOpen {
          ExpandedPanelView(model: model, host: host, notchHeight: geometry.notchRect.height)
            .frame(width: canvas.width, height: canvas.height)
            .transition(Self.contentTransition)
        } else if state == .peek, let activity = host.liveActivities.current {
          PeekView(
            activity: activity, notchWidth: geometry.notchRect.width,
            sideWidth: geometry.layout.peekExtraWidth
          )
          .frame(height: geometry.notchRect.height)
          .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
      }
      .frame(width: size.width, height: size.height, alignment: .top)
      .clipShape(shape)
      .overlay {
        if state.isOpen {
          PanelEdge(shape: shape)
            .transition(.opacity)
        }
      }
      .background {
        PanelBackground(
          shape: shape, material: material, theme: theme,
          shadowOpacity: theme.shadow && state.isOpen ? 0.45 : 0)
      }
      .contentShape(shape)
      .onTapGesture { model.send(.clicked) }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .foregroundStyle(theme.foreground.color)
      .tint(theme.accent.color)
      .fontDesign(theme.fontDesign.swiftUI)
      .animation(animation(for: state, theme: theme), value: state)
      .animation(.smooth(duration: 0.25), value: theme)
      .environment(\.colorScheme, .dark)
    }
  }

  /// Opening uses the theme's spring; closing is always critically damped and a bit faster.
  private func animation(for state: NotchState, theme: Theme) -> Animation {
    state.isOpen
      ? .spring(response: theme.spring.response, dampingFraction: theme.spring.damping)
      : .spring(response: theme.spring.response * 0.85, dampingFraction: 1)
  }

  /// Content materializes once the shape is mostly open and fades out quickly on close.
  private static let contentTransition = AnyTransition.asymmetric(
    insertion: .materialize.animation(.easeOut(duration: 0.26).delay(0.1)),
    removal: .opacity.animation(.easeIn(duration: 0.08)))
}

/// Fill of the panel shape for the theme's material.
private struct PanelBackground: View {
  let shape: NotchShape
  let material: Theme.Material
  let theme: Theme
  let shadowOpacity: Double

  var body: some View {
    Group {
      switch material {
      case .solid:
        shape.fill(theme.background.color)
      case .glass:
        Color.clear.glassEffect(.regular, in: shape)
      case .tinted:
        Color.clear.glassEffect(.regular.tint(theme.tint.color), in: shape)
      }
    }
    .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 8)
  }
}

/// Tabs and pin button beside the camera housing, widgets below.
private struct ExpandedPanelView: View {
  let model: NotchViewModel
  let host: WidgetHost
  let notchHeight: CGFloat

  private var isPinned: Bool { model.state == .pinned }

  var body: some View {
    VStack(spacing: 0) {
      // Top band beside the camera housing.
      HStack {
        WidgetTabBar(host: host)
        Spacer()
        Button {
          model.send(.pinToggled)
        } label: {
          Image(systemName: isPinned ? "pin.fill" : "pin")
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PanelButtonStyle(isSelected: isPinned))
        .help(isPinned ? Text("Unpin panel") : Text("Pin panel"))
        .accessibilityLabel(isPinned ? Text("Unpin panel") : Text("Pin panel"))
      }
      .frame(height: notchHeight)

      if let request = host.permissionBanner {
        PermissionCard(request: request, waiting: host.claude.permissions.pending.count - 1) {
          decision in
          host.claude.answer(request, with: decision)
        }
        .id(request.id)
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 8)
      } else {
        WidgetRow(host: host, secondary: model.theme.secondary.color)
          .padding(.top, 8)
      }
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 14)
  }
}

extension Theme.FontDesign {
  var swiftUI: Font.Design {
    switch self {
    case .default: .default
    case .rounded: .rounded
    case .monospaced: .monospaced
    case .serif: .serif
    }
  }
}

/// Hosting view that reacts to the first click even though the panel never becomes key.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }
}
