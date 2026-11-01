import Foundation

/// Look of the notch panel; its size is `PanelSize`, the same for every theme. Decoding is
/// tolerant: unknown keys are ignored and missing or invalid values fall back to defaults,
/// so older theme files keep working.
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

  struct Spring: Codable, Equatable, Sendable {
    var response: Double
    var damping: Double
  }

  var id: String
  var name: String
  var material = Material.solid
  var tint = HexColor(red: 0x1E, green: 0x3A, blue: 0x8A)
  var background = HexColor(red: 0x00, green: 0x00, blue: 0x00)
  /// With a solid material, the background fades into this color towards the bottom.
  var gradient: HexColor?
  var foreground = HexColor(red: 0xFF, green: 0xFF, blue: 0xFF)
  var secondary = HexColor(red: 0x9C, green: 0xA3, blue: 0xAF)
  var accent = HexColor(red: 0x3B, green: 0x82, blue: 0xF6)
  var cornerRadius = 24.0
  /// Saved as `animation`; renamed in Swift because `Binding` has an `animation` method.
  var spring = Spring(response: 0.36, damping: 1)
  var fontDesign = FontDesign.default
  var shadow = true
  /// A neon line around the open panel that fades from this color into the accent.
  var glow: HexColor?
  /// Panel size from a theme file saved before size became an app setting. Read once to
  /// carry it over; never saved.
  var legacySize: PanelSize?

  init(id: String, name: String) {
    self.id = id
    self.name = name
  }

  /// Keeps values in ranges the panel can draw.
  func normalized() -> Theme {
    var theme = self
    theme.cornerRadius = cornerRadius.clamped(to: Self.cornerRadiusRange)
    theme.spring.response = spring.response.clamped(to: Self.responseRange)
    theme.spring.damping = spring.damping.clamped(to: Self.dampingRange)
    return theme
  }

  static let cornerRadiusRange = 0.0...60
  static let responseRange = 0.1...1.2
  /// Below 0.7 the panel wobbles past the notch, which reads as cheap rather than lively.
  static let dampingRange = 0.7...1.0
}

extension Theme {
  private enum CodingKeys: String, CodingKey {
    case id, name, material, tint, background, gradient, foreground, secondary, accent,
      cornerRadius, fontDesign, shadow, glow
    case spring = "animation"
  }

  /// Size keys of theme files from before `PanelSize`.
  private enum LegacyKeys: String, CodingKey {
    case expandedSize, peekExtraWidth, textScale
  }

  private struct LegacyExpandedSize: Decodable {
    var width: Double
    var height: Double
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
    gradient = value(.gradient, defaults.gradient)
    foreground = value(.foreground, defaults.foreground)
    secondary = value(.secondary, defaults.secondary)
    accent = value(.accent, defaults.accent)
    cornerRadius = value(.cornerRadius, defaults.cornerRadius)
    spring = value(.spring, defaults.spring)
    fontDesign = value(.fontDesign, defaults.fontDesign)
    shadow = value(.shadow, defaults.shadow)
    glow = value(.glow, defaults.glow)
    legacySize = Self.legacySize(from: decoder)
    self = normalized()
  }

  private static func legacySize(from decoder: Decoder) -> PanelSize? {
    guard let container = try? decoder.container(keyedBy: LegacyKeys.self),
      !container.allKeys.isEmpty
    else { return nil }
    var size = PanelSize()
    if let expanded = try? container.decode(LegacyExpandedSize.self, forKey: .expandedSize) {
      size.width = expanded.width
      size.height = expanded.height
    }
    if let width = try? container.decode(Double.self, forKey: .peekExtraWidth) {
      size.indicatorWidth = width
    }
    if let scale = try? container.decode(Double.self, forKey: .textScale) {
      size.textScale = scale
    }
    return size.normalized()
  }
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
