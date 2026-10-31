import AppKit
import SwiftUI

/// Root of the notch panel. The window has a fixed size; only the shape inside it grows
/// and shrinks, which keeps the animation smooth.
struct NotchRootView: View {
  let model: NotchViewModel

  var body: some View {
    if let geometry = model.geometry {
      let size = geometry.shapeSize(for: model.state)
      let isOpen = model.state.isOpen
      let shape = NotchShape(topRadius: isOpen ? 12 : 6, bottomRadius: isOpen ? 22 : 10)

      shape
        .fill(.black)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) {
          if isOpen {
            ExpandedPanelView(model: model, notchHeight: geometry.notchRect.height)
              .transition(.opacity)
          }
        }
        .contentShape(shape)
        .onTapGesture { model.send(.clicked) }
        .shadow(color: .black.opacity(isOpen ? 0.4 : 0), radius: 12, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: model.state)
        .environment(\.colorScheme, .dark)
    }
  }
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
