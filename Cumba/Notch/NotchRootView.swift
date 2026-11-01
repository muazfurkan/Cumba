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
      // Opening the panel ends the greeting.
      let isGreeting = model.isGreeting && !state.isOpen
      let size = isGreeting ? geometry.greetingSize : geometry.shapeSize(for: state)
      let canvas = geometry.shapeSize(for: .expanded)
      let shape = NotchShape(
        topRadius: state.isOpen || isGreeting ? 14 : 6,
        bottomRadius: state.isOpen ? theme.cornerRadius : isGreeting ? 26 : 10)
      // Over the hardware notch the closed shape is plain black so it blends in, and the
      // greeting is black like a new Mac's.
      let isBlended = (state == .closed || isGreeting) && !geometry.isVirtual

      VStack(spacing: 8) {
        ZStack(alignment: .top) {
          if isGreeting {
            HelloView()
              .frame(width: 260, height: 120)
              .padding(.top, geometry.notchRect.height + 4)
              .transition(.opacity.animation(.easeOut(duration: 0.3)))
          } else if state.isOpen {
            ExpandedPanelView(model: model, host: host, notchHeight: geometry.notchRect.height)
              .frame(width: canvas.width, height: canvas.height)
              .transition(Self.contentTransition)
          } else if state == .peek, let activity = host.liveActivities.current {
            PeekView(
              activity: activity, notchWidth: geometry.notchRect.width,
              sideWidth: geometry.peekSideWidth, height: geometry.peekRowHeight,
              openPanel: { model.send(.clicked) }
            )
            .frame(height: geometry.shapeSize(for: .peek).height, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
          }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .overlay {
          if state.isOpen {
            if let glow = theme.glow {
              NeonEdge(shape: shape, colors: [glow.color, theme.accent.color])
                .transition(.opacity)
            } else {
              PanelEdge(shape: shape)
                .transition(.opacity)
            }
          }
        }
        .background {
          PanelBackground(
            shape: shape, theme: theme, isBlended: isBlended,
            shadowOpacity: theme.shadow && (state.isOpen || isGreeting) ? 0.45 : 0)
        }
        .contentShape(shape)
        .onTapGesture { model.send(.clicked) }
        // Tabs in a bar of their own come in under the panel once it's open.
        if state.isOpen, model.tabBarStyle.isFloating, host.tabs.count > 1 {
          FloatingTabBar(host: host, style: model.tabBarStyle, theme: theme)
            .transition(Self.tabBarTransition)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .foregroundStyle(theme.foreground.color)
      .tint(theme.accent.color)
      .environment(\.indicatorColors, theme.indicatorColors)
      .environment(\.widgetStyle, model.widgetStyle)
      .fontDesign(theme.fontDesign.swiftUI)
      .environment(\.panelTextScale, model.textScale)
      .animation(animation(for: state, theme: theme), value: state)
      .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.isGreeting)
      .animation(.smooth(duration: 0.25), value: theme)
      .animation(.smooth(duration: 0.3), value: geometry.layout.peekExtraWidth)
      .animation(.smooth(duration: 0.35), value: geometry.layout.peekNotificationHeight)
      .animation(.smooth(duration: 0.3), value: geometry.layout.panelWidth)
      .animation(.smooth(duration: 0.3), value: geometry.layout.panelHeight)
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

  private static let tabBarTransition = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .offset(y: -10)).combined(with: .scale(scale: 0.9))
      .animation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.08)),
    removal: .opacity.animation(.easeIn(duration: 0.08)))

  /// Content materializes once the shape is mostly open and fades out quickly on close.
  private static let contentTransition = AnyTransition.asymmetric(
    insertion: .materialize.animation(.easeOut(duration: 0.26).delay(0.1)),
    removal: .opacity.animation(.easeIn(duration: 0.08)))
}

/// Fill of the panel shape for the theme's material.
private struct PanelBackground: View {
  let shape: NotchShape
  let theme: Theme
  /// Plain black, to blend into the hardware notch.
  let isBlended: Bool
  let shadowOpacity: Double
  /// Reduce Transparency replaces glass with an opaque fill of the same character.
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  /// Top and bottom of a solid fill; the same color twice without a gradient.
  private var solidColors: [Color] {
    if isBlended {
      return [.black, .black]
    }
    return [theme.background.color, (theme.gradient ?? theme.background).color]
  }

  var body: some View {
    Group {
      switch isBlended ? .solid : theme.material {
      case .solid:
        shape.fill(LinearGradient(colors: solidColors, startPoint: .top, endPoint: .bottom))
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
  private var style: AppSettings.TabBarStyle { model.tabBarStyle }
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
        } else if style == .top {
          WidgetTabBar(host: host)
          Spacer()
        } else {
          Spacer()
          // With the tabs under the panel, adding and editing sit here.
          if style.isFloating {
            TabActions(host: host)
          }
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

      if style == .inPanel {
        WidgetTabBar(host: host)
          .frame(height: NotchLayout.bottomTabBarHeight)
      }
    }
    .padding(.horizontal, 28)
    .padding(.bottom, style == .inPanel ? 4 : 14)
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
      TabPager(host: host, secondary: secondary)
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
