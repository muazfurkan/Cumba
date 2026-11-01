import Foundation

/// How large the panel and its text are. The same for every theme, so switching themes
/// keeps it. Decoding is tolerant like `Theme`.
struct PanelSize: Codable, Equatable, Sendable {
  var width = 640.0
  var height = 190.0
  /// Width added on each side of the notch while it shows an activity.
  var indicatorWidth = 70.0
  /// Size of text in the panel, as a factor of the macOS text styles.
  var textScale = 1.2
  /// How far the closed notch reaches past the camera housing on each side.
  var closedWidth = 8.0
  /// How far the closed notch reaches below the camera housing.
  var closedHeight = 5.0

  init() {}

  /// Keeps values in ranges the panel can draw.
  func normalized() -> PanelSize {
    var size = self
    size.width = width.clamped(to: Self.widthRange)
    size.height = height.clamped(to: Self.heightRange)
    size.indicatorWidth = indicatorWidth.clamped(to: Self.indicatorWidthRange)
    size.textScale = textScale.clamped(to: Self.textScaleRange)
    size.closedWidth = closedWidth.clamped(to: Self.closedWidthRange)
    size.closedHeight = closedHeight.clamped(to: Self.closedHeightRange)
    return size
  }

  static let widthRange = 360.0...1000
  static let heightRange = 120.0...480
  static let indicatorWidthRange = 0.0...200
  static let textScaleRange = 0.9...1.6
  static let closedWidthRange = 0.0...30
  static let closedHeightRange = 0.0...20
}

extension PanelSize {
  private enum CodingKeys: String, CodingKey {
    case width, height, indicatorWidth, textScale, closedWidth, closedHeight
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init()

    func value(_ key: CodingKeys, _ fallback: Double) -> Double {
      (try? container.decodeIfPresent(Double.self, forKey: key)) ?? fallback
    }

    width = value(.width, width)
    height = value(.height, height)
    indicatorWidth = value(.indicatorWidth, indicatorWidth)
    textScale = value(.textScale, textScale)
    closedWidth = value(.closedWidth, closedWidth)
    closedHeight = value(.closedHeight, closedHeight)
    self = normalized()
  }
}
