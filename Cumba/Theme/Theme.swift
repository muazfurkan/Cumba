import Foundation

/// Look of the notch panel. Decoding is tolerant: unknown keys are ignored and
/// missing or invalid values fall back to defaults, so older theme files keep working.
struct Theme: Codable, Equatable, Identifiable, Sendable {
  enum Material: String, Codable, CaseIterable, Sendable {
    /// Liquid Glass.
    case glass
    /// Plain black that blends into the hardware notch.
    case solid
    /// Glass tinted with `tint`.
    case tinted
  }

  enum FontDesign: String, Codable, CaseIterable, Sendable {
    case `default`, rounded, monospaced, serif
  }

  struct Size: Codable, Equatable, Sendable {
    var width: Double
    var height: Double
  }

  struct Spring: Codable, Equatable, Sendable {
    var response: Double
    var damping: Double
  }

  var id: String
  var name: String
  var material = Material.solid
  var tint = HexColor(red: 0x1E, green: 0x3A, blue: 0x8A)
  var background = HexColor(red: 0x00, green: 0x00, blue: 0x00)
  var foreground = HexColor(red: 0xFF, green: 0xFF, blue: 0xFF)
  var secondary = HexColor(red: 0x9C, green: 0xA3, blue: 0xAF)
  var accent = HexColor(red: 0x3B, green: 0x82, blue: 0xF6)
  var cornerRadius = 24.0
  var expandedSize = Size(width: 640, height: 190)
  var peekExtraWidth = 70.0
  /// Saved as `animation`; renamed in Swift because `Binding` has an `animation` method.
  var spring = Spring(response: 0.36, damping: 1)
  var fontDesign = FontDesign.default
  /// Size of text in the panel, as a factor of the macOS text styles.
  var textScale = 1.2
  var shadow = true

  init(id: String, name: String) {
    self.id = id
    self.name = name
  }

  /// Keeps values in ranges the panel can draw.
  func normalized() -> Theme {
    var theme = self
    theme.cornerRadius = cornerRadius.clamped(to: Self.cornerRadiusRange)
    theme.expandedSize.width = expandedSize.width.clamped(to: Self.widthRange)
    theme.expandedSize.height = expandedSize.height.clamped(to: Self.heightRange)
    theme.peekExtraWidth = peekExtraWidth.clamped(to: Self.peekWidthRange)
    theme.spring.response = spring.response.clamped(to: Self.responseRange)
    theme.spring.damping = spring.damping.clamped(to: Self.dampingRange)
    theme.textScale = textScale.clamped(to: Self.textScaleRange)
    return theme
  }

  static let cornerRadiusRange = 0.0...60
  static let widthRange = 360.0...1000
  static let heightRange = 120.0...480
  static let peekWidthRange = 0.0...200
  static let responseRange = 0.1...1.2
  /// Below 0.7 the panel wobbles past the notch, which reads as cheap rather than lively.
  static let dampingRange = 0.7...1.0
  static let textScaleRange = 0.9...1.6
}

extension Theme {
  private enum CodingKeys: String, CodingKey {
    case id, name, material, tint, background, foreground, secondary, accent, cornerRadius,
      expandedSize, peekExtraWidth, fontDesign, textScale, shadow
    case spring = "animation"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = Theme(id: "", name: "")

    func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
      (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    id = value(.id, defaults.id)
    name = value(.name, defaults.name)
    material = value(.material, defaults.material)
    tint = value(.tint, defaults.tint)
    background = value(.background, defaults.background)
    foreground = value(.foreground, defaults.foreground)
    secondary = value(.secondary, defaults.secondary)
    accent = value(.accent, defaults.accent)
    cornerRadius = value(.cornerRadius, defaults.cornerRadius)
    expandedSize = value(.expandedSize, defaults.expandedSize)
    peekExtraWidth = value(.peekExtraWidth, defaults.peekExtraWidth)
    spring = value(.spring, defaults.spring)
    fontDesign = value(.fontDesign, defaults.fontDesign)
    textScale = value(.textScale, defaults.textScale)
    shadow = value(.shadow, defaults.shadow)
    self = normalized()
  }
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
