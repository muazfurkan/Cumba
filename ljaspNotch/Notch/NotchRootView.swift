import AppKit
import SwiftUI

/// Root of the notch panel. The window has a fixed size; only the shape inside it grows
/// and shrinks. Content is laid out once at full size and revealed by the growing shape,
/// so nothing reflows while the panel animates.
struct NotchRootView: View {
  let model: NotchViewModel

  // Critically damped, so the panel grows out of the notch without overshooting.
  private static let openAnimation = Animation.spring(response: 0.36, dampingFraction: 1)
  private static let closeAnimation = Animation.spring(response: 0.3, dampingFraction: 1)

  var body: some View {
    if let geometry = model.geometry {
      let state = model.state
      let size = geometry.shapeSize(for: state)
      let canvas = geometry.shapeSize(for: .expanded)
      let shape = NotchShape(
        topRadius: state.isOpen ? 14 : 6, bottomRadius: state.isOpen ? 24 : 10)

      ZStack(alignment: .top) {
        if state.isOpen {
          ExpandedPanelView(model: model, notchHeight: geometry.notchRect.height)
            .frame(width: canvas.width, height: canvas.height)
            .transition(Self.contentTransition)
        }
      }
      .frame(width: size.width, height: size.height, alignment: .top)
      .background(.black)
      .clipShape(shape)
      .background {
        shape
          .fill(.black)
          .shadow(color: .black.opacity(state.isOpen ? 0.45 : 0), radius: 18, y: 8)
      }
      .contentShape(shape)
      .onTapGesture { model.send(.clicked) }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .animation(state.isOpen ? Self.openAnimation : Self.closeAnimation, value: state)
      .environment(\.colorScheme, .dark)
    }
  }

  /// Content fades in once the shape is mostly open and fades out quickly on close.
  private static let contentTransition = AnyTransition.asymmetric(
    insertion: .opacity
      .combined(with: .scale(scale: 0.97, anchor: .top))
      .animation(.easeOut(duration: 0.22).delay(0.12)),
    removal: .opacity.animation(.easeIn(duration: 0.08)))
}

/// Placeholder content until widgets arrive in Phase 3.
private struct ExpandedPanelView: View {
  let model: NotchViewModel
  let notchHeight: CGFloat

  private var isPinned: Bool { model.state == .pinned }

  var body: some View {
    VStack(spacing: 0) {
      // Top band beside the camera housing.
      HStack {
        Text("ljaspNotch")
          .font(.headline)
        Spacer()
        Button {
          model.send(.pinToggled)
        } label: {
          Image(systemName: isPinned ? "pin.fill" : "pin")
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isPinned ? Text("Unpin panel") : Text("Pin panel"))
        .accessibilityLabel(isPinned ? Text("Unpin panel") : Text("Pin panel"))
      }
      .frame(height: notchHeight)

      Spacer()
      Text("Widgets are coming soon.")
        .foregroundStyle(.secondary)
      Spacer()
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 32)
    .padding(.bottom, 12)
  }
}

/// Hosting view that reacts to the first click even though the panel never becomes key.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }
}
