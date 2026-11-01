import AppKit
import CoreImage
import QuartzCore
import SwiftUI

/// "hello" written out under the notch, like a new Mac says it: on the first launch and
/// from Settings > General. With Reduce Motion the word fades in instead.
struct HelloView: NSViewRepresentable {
  /// How long the notch shows the word: the shape opening, the writing and a moment to read.
  static let duration = Duration.milliseconds(4300)

  func makeNSView(context: Context) -> HelloStrokeView {
    HelloStrokeView(fadesIn: context.environment.accessibilityReduceMotion)
  }

  func updateNSView(_ view: HelloStrokeView, context: Context) {}
}

/// Writes the word with Core Animation: the system moves the pen, so it stays smooth even
/// while the app is busy starting up.
final class HelloStrokeView: NSView {
  /// The colors of a new Mac's greeting, from left to right.
  private static let colors = [
    NSColor(srgbRed: 0.36, green: 0.78, blue: 1, alpha: 1),
    NSColor(srgbRed: 0.56, green: 0.5, blue: 1, alpha: 1),
    NSColor(srgbRed: 0.95, green: 0.42, blue: 0.75, alpha: 1),
    NSColor(srgbRed: 1, green: 0.58, blue: 0.35, alpha: 1),
    NSColor(srgbRed: 1, green: 0.82, blue: 0.35, alpha: 1),
  ]
  private static let delay: CFTimeInterval = 0.35
  private static let writingTime: CFTimeInterval = 2.7
  private static let lineWidth: CGFloat = 5

  private let fadesIn: Bool
  private let ink = CAGradientLayer()
  private let inkStroke = CAShapeLayer()
  /// A blurred copy under the ink, for a soft glow of the same colors.
  private let glow = CALayer()
  private let glowInk = CAGradientLayer()
  private let glowStroke = CAShapeLayer()
  private var hasStarted = false

  init(fadesIn: Bool) {
    self.fadesIn = fadesIn
    super.init(frame: .zero)
    wantsLayer = true
    layerUsesCoreImageFilters = true
    setAccessibilityElement(true)
    setAccessibilityRole(.image)
    setAccessibilityLabel(
      String(
        localized: "Hello", comment: "Accessibility label of the hello written under the notch"))
    for gradient in [ink, glowInk] {
      gradient.colors = Self.colors.map(\.cgColor)
      gradient.startPoint = CGPoint(x: 0, y: 0.5)
      gradient.endPoint = CGPoint(x: 1, y: 0.5)
    }
    for stroke in [inkStroke, glowStroke] {
      stroke.fillColor = nil
      stroke.strokeColor = NSColor.white.cgColor
      stroke.lineWidth = Self.lineWidth
      stroke.lineCap = .round
      stroke.lineJoin = .round
      stroke.strokeEnd = 0
    }
    ink.mask = inkStroke
    glowInk.mask = glowStroke
    glow.addSublayer(glowInk)
    glow.opacity = 0.7
    if let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 6]) {
      glow.filters = [blur]
    }
    layer?.addSublayer(glow)
    layer?.addSublayer(ink)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("Not used")
  }

  override func layout() {
    super.layout()
    updateLayers()
  }

  /// Sizes the layers and draws the word into this view's bounds.
  private func updateLayers() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for layer in [ink, inkStroke, glow, glowInk, glowStroke] {
      layer.frame = bounds
    }
    // The design has y going down; flip it unless the layers already do.
    var path = HelloShape().path(in: bounds).cgPath
    var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
    if !inkStroke.contentsAreFlipped(), let flipped = path.copy(using: &flip) {
      path = flipped
    }
    inkStroke.path = path
    glowStroke.path = path
    CATransaction.commit()
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    let scale = window?.backingScaleFactor ?? 2
    for layer in [ink, inkStroke, glow, glowInk, glowStroke] {
      layer.contentsScale = scale
    }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil, !hasStarted else { return }
    hasStarted = true
    // Whether the layers are flipped is known only once the view is in a window.
    updateLayers()
    write()
  }

  /// The pen's pace comes from the word's shape (`HelloShape.pace`); the whole stroke also
  /// starts and ends gently.
  private func write() {
    let start = CACurrentMediaTime() + Self.delay
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    inkStroke.strokeEnd = 1
    glowStroke.strokeEnd = 1
    CATransaction.commit()
    if fadesIn {
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = 0
      fade.toValue = 1
      fade.duration = 0.5
      fade.beginTime = start
      fade.fillMode = .backwards
      layer?.add(fade, forKey: "fade")
      return
    }
    let pace = HelloShape.pace()
    let writing = CAKeyframeAnimation(keyPath: "strokeEnd")
    writing.values = pace.values
    writing.keyTimes = pace.times.map { NSNumber(value: $0) }
    writing.duration = Self.writingTime
    writing.beginTime = start
    writing.fillMode = .backwards
    writing.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0, 0.3, 1)
    inkStroke.add(writing, forKey: "write")
    glowStroke.add(writing, forKey: "write")
  }
}
