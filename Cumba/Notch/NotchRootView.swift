import AppKit
import SwiftUI

/// Root of the notch panel. The window has a fixed size; only the shape inside it grows
/// and shrinks. Content is laid out once at full size and revealed by the growing shape,
/// so nothing reflows while the panel animates.
struct NotchRootView: View {
  let model: NotchViewModel
  let host: WidgetHost
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            sideWidth: geometry.layout.peekExtraWidth, height: geometry.notchRect.height
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
      .environment(\.panelTextScale, theme.textScale)
      .animation(animation(for: state, theme: theme), value: state)
      .animation(.smooth(duration: 0.25), value: theme)
      .animation(.smooth(duration: 0.3), value: geometry.layout.peekExtraWidth)
      .animation(.smooth(duration: 0.3), value: geometry.layout.panelWidth)
      .environment(\.colorScheme, .dark)
    }
  }

  /// Opening uses the theme's spring; closing is always critically damped and a bit faster.
  /// With Reduce Motion on, both are a short ease without any bounce.
  private func animation(for state: NotchState, theme: Theme) -> Animation {
    if reduceMotion {
      return .easeOut(duration: 0.18)
    }
    return state.isOpen
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
  /// Reduce Transparency replaces glass with an opaque fill of the same character.
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    Group {
      switch material {
      case .solid:
        shape.fill(theme.background.color)
      case .glass where reduceTransparency:
        shape.fill(Color(white: 0.11))
      case .tinted where reduceTransparency:
        shape.fill(theme.tint.color.mix(with: .black, by: 0.75))
      case .glass:
        Color.clear.glassEffect(.regular, in: shape)
      case .tinted:
        Color.clear.glassEffect(.regular.tint(theme.tint.color), in: shape)
      }
    }
    .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 8)
  }
}

/// The pin button beside the camera housing, the open tab's widgets (or the gallery or the
/// tab editor) below, and the tabs at the top or bottom.
private struct ExpandedPanelView: View {
  let model: NotchViewModel
  let host: WidgetHost
  let notchHeight: CGFloat

  private var isPinned: Bool { model.state == .pinned }
  private var tabsAtTop: Bool { model.tabBarPosition == .top }
  private var secondary: Color { model.theme.secondary.color }

  /// Gallery or editor, which replace the widgets until Done.
  private var modeTitle: Text? {
    if host.isShowingGallery {
      return Text("Add a Widget")
    }
    if host.isEditing {
      return Text("Edit Tab")
    }
    return nil
  }

  var body: some View {
    VStack(spacing: 0) {
      // Top band beside the camera housing.
      HStack {
        if let modeTitle {
          modeTitle
            .panelFont(.headline)
          Spacer()
          Button("Done") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              host.showGallery(false)
              host.setEditing(false)
            }
          }
          .buttonStyle(.plain)
          .panelFont(.callout, weight: .semibold)
          .foregroundStyle(model.theme.accent.color)
        } else if tabsAtTop {
          WidgetTabBar(host: host)
          Spacer()
        } else {
          Spacer()
        }
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

      content
        .padding(.top, 8)
        .frame(maxHeight: .infinity)

      if !tabsAtTop {
        WidgetTabBar(host: host)
          .frame(height: NotchLayout.bottomTabBarHeight)
      }
    }
    .padding(.horizontal, 28)
    .padding(.bottom, tabsAtTop ? 14 : 4)
  }

  @ViewBuilder private var content: some View {
    if let request = host.permissionBanner {
      PermissionCard(request: request, waiting: host.claude.permissions.pending.count - 1) {
        decision in
        host.claude.answer(request, with: decision)
      }
      .id(request.id)
      .padding(10)
      .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    } else if host.isShowingGallery {
      WidgetGallery(host: host, secondary: secondary)
        .transition(.opacity)
    } else if host.isEditing {
      TabEditor(host: host, secondary: secondary)
        .transition(.opacity)
    } else {
      WidgetRow(host: host, secondary: secondary)
        .transition(.opacity)
    }
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
  /// Builds the menu shown on right-click or Control-click anywhere on the notch.
  var makeContextMenu: (() -> NSMenu)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  /// Clicks on SwiftUI content don't make the panel key; only text views inside do.
  override var needsPanelToBecomeKey: Bool { false }

  /// A SwiftUI context menu under the pointer (a widget's, or a tray file's) comes first,
  /// followed by the notch's own items.
  override func menu(for event: NSEvent) -> NSMenu? {
    let own = makeContextMenu?()
    guard let content = super.menu(for: event), !content.items.isEmpty else { return own }
    if let own {
      content.addItem(.separator())
      for item in own.items {
        own.removeItem(item)
        content.addItem(item)
      }
    }
    return content
  }
}

/// A menu item that runs a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
  private let handler: @MainActor () -> Void

  init(title: String, handler: @escaping @MainActor () -> Void) {
    self.handler = handler
    super.init(title: title, action: #selector(run), keyEquivalent: "")
    target = self
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("Not used")
  }

  @objc private func run() {
    handler()
  }
}
