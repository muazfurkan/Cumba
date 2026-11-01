import SwiftUI

/// "hello" written in one connected stroke, drawn for Cumba. Trimming it from 0 to 1 writes
/// the word the way a pen would.
struct HelloShape: Shape {
  /// The design's own coordinate space; the path is scaled to fit the rect it's drawn in.
  static let designSize = CGSize(width: 360, height: 180)

  /// A cubic curve from where the last one ended, in design coordinates.
  private struct Curve {
    let to, c1, c2: CGPoint

    init(_ to: (CGFloat, CGFloat), _ c1: (CGFloat, CGFloat), _ c2: (CGFloat, CGFloat)) {
      self.to = CGPoint(x: to.0, y: to.1)
      self.c1 = CGPoint(x: c1.0, y: c1.1)
      self.c2 = CGPoint(x: c2.0, y: c2.1)
    }
  }

  private static let start = CGPoint(x: 20, y: 150)
  private static let curves: [Curve] = [
    // h: up into the loop, down the stem, over the hump.
    Curve((100, 60), (55, 140), (95, 90)),
    Curve((88, 28), (104, 40), (98, 28)),
    Curve((62, 160), (78, 28), (66, 120)),
    Curve((95, 110), (64, 135), (75, 110)),
    Curve((128, 162), (115, 108), (110, 160)),
    // e
    Curve((174, 124), (150, 160), (170, 140)),
    Curve((162, 108), (177, 114), (170, 108)),
    Curve((150, 148), (152, 108), (146, 130)),
    Curve((178, 160), (153, 162), (168, 163)),
    // l
    Curve((215, 62), (195, 152), (212, 95)),
    Curve((203, 28), (218, 42), (213, 28)),
    Curve((185, 150), (193, 28), (186, 110)),
    Curve((216, 160), (186, 162), (205, 164)),
    // l
    Curve((253, 62), (233, 152), (250, 95)),
    Curve((241, 28), (256, 42), (251, 28)),
    Curve((223, 150), (231, 28), (224, 110)),
    Curve((248, 160), (224, 162), (238, 163)),
    // o: up its left side to the top, around, then the little loop and the tail.
    Curve((262, 128), (256, 160), (260, 142)),
    Curve((284, 111), (264, 116), (274, 111)),
    Curve((264, 136), (272, 111), (264, 124)),
    Curve((284, 161), (264, 150), (273, 161)),
    Curve((304, 136), (296, 161), (304, 150)),
    Curve((286, 111), (304, 122), (296, 111)),
    Curve((300, 121), (282, 113), (288, 122)),
    Curve((336, 108), (312, 120), (326, 114)),
  ]

  func path(in rect: CGRect) -> Path {
    let size = Self.designSize
    let scale = min(rect.width / size.width, rect.height / size.height)
    let origin = CGPoint(
      x: rect.midX - size.width * scale / 2, y: rect.midY - size.height * scale / 2)
    func place(_ point: CGPoint) -> CGPoint {
      CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }
    var path = Path()
    path.move(to: place(Self.start))
    for curve in Self.curves {
      path.addCurve(to: place(curve.to), control1: place(curve.c1), control2: place(curve.c2))
    }
    return path
  }
}

/// "hello" written out under the notch, like a new Mac says it: on the first launch and
/// from Settings > General. With Reduce Motion the word fades in instead.
struct HelloView: View {
  @State private var progress = 0.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// How long the notch shows the word: the shape opening, the writing and a moment to read.
  static let duration = Duration.milliseconds(3900)
  private static let writingTime = 2.4

  /// The colors of a new Mac's greeting, from left to right.
  private static let ink = LinearGradient(
    colors: [
      Color(red: 0.36, green: 0.78, blue: 1),
      Color(red: 0.56, green: 0.5, blue: 1),
      Color(red: 0.95, green: 0.42, blue: 0.75),
      Color(red: 1, green: 0.58, blue: 0.35),
      Color(red: 1, green: 0.82, blue: 0.35),
    ], startPoint: .leading, endPoint: .trailing)

  var body: some View {
    let style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
    let word = HelloShape().trim(from: 0, to: reduceMotion ? 1 : progress)
    word.stroke(Self.ink, style: style)
      // A soft glow of the same colors.
      .background { word.stroke(Self.ink, style: style).blur(radius: 7).opacity(0.7) }
      .opacity(reduceMotion ? progress : 1)
      .accessibilityElement()
      .accessibilityLabel(Text("Hello"))
      .onAppear {
        withAnimation(
          reduceMotion
            ? .easeOut(duration: 0.5).delay(0.3)
            : .easeInOut(duration: Self.writingTime).delay(0.35)
        ) {
          progress = 1
        }
      }
  }
}
