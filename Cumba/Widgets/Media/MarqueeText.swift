import SwiftUI

/// One line of text that scrolls like a ticker when it doesn't fit, pausing at the start of
/// each pass. It stays still when it fits or with Reduce Motion, and it only animates while
/// on screen.
struct MarqueeText: View {
  let text: String
  /// Points per second.
  var speed: CGFloat = 28
  var pause: Duration = .seconds(1.5)

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var textWidth: CGFloat = 0
  @State private var boxWidth: CGFloat = 0
  @State private var offset: CGFloat = 0

  private static let gap: CGFloat = 36
  private static let fade: CGFloat = 8

  private var scrolls: Bool { !reduceMotion && textWidth > boxWidth && boxWidth > 0 }

  var body: some View {
    // Takes the width it's offered (never the text's own) and one line's height; the
    // scrolling copies sit on top and are clipped to it.
    Text(text)
      .lineLimit(1)
      .minimumScaleFactor(1)
      .hidden()
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .leading) {
        HStack(spacing: Self.gap) {
          label
          if scrolls {
            label
          }
        }
        .offset(x: offset)
      }
      .clipped()
      .mask {
        if scrolls {
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: Self.fade / max(boxWidth, 1)),
              .init(color: .black, location: 1 - Self.fade / max(boxWidth, 1)),
              .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        } else {
          Rectangle()
        }
      }
      .onGeometryChange(for: CGFloat.self, of: \.size.width) { boxWidth = $0 }
      .task(id: [text, String(describing: scrolls), String(describing: textWidth)]) {
        await scroll()
      }
      .accessibilityElement()
      .accessibilityLabel(Text(text))
  }

  private var label: some View {
    Text(text)
      .fixedSize()
      .onGeometryChange(for: CGFloat.self, of: \.size.width) { textWidth = $0 }
  }

  /// One pass moves the text left by its width plus the gap, where the copy behind it sits
  /// exactly where the text started, then jumps back without animation.
  private func scroll() async {
    offset = 0
    guard scrolls else { return }
    let distance = textWidth + Self.gap
    let duration = Double(distance / speed)
    while !Task.isCancelled {
      do {
        try await Task.sleep(for: pause)
        withAnimation(.linear(duration: duration)) { offset = -distance }
        try await Task.sleep(for: .seconds(duration))
      } catch {
        return
      }
      var reset = Transaction()
      reset.disablesAnimations = true
      withTransaction(reset) { offset = 0 }
    }
  }
}
