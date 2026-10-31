import AppKit
import SwiftUI

/// sRGB color stored as `#RRGGBB` or `#RRGGBBAA` in theme files. Components are kept as
/// bytes so a color survives saving and loading unchanged.
struct HexColor: Equatable, Hashable, Sendable {
  var red: UInt8
  var green: UInt8
  var blue: UInt8
  var alpha: UInt8 = 255

  init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  /// Parses `#RRGGBB`, `#RRGGBBAA` or the same without `#`. Returns nil for anything else.
  init?(hex: String) {
    var digits = hex.trimmingCharacters(in: .whitespaces)
    if digits.hasPrefix("#") {
      digits.removeFirst()
    }
    guard digits.count == 6 || digits.count == 8, let value = UInt32(digits, radix: 16) else {
      return nil
    }
    let hasAlpha = digits.count == 8
    let rgb = hasAlpha ? value >> 8 : value
    red = UInt8((rgb >> 16) & 0xFF)
    green = UInt8((rgb >> 8) & 0xFF)
    blue = UInt8(rgb & 0xFF)
    alpha = hasAlpha ? UInt8(value & 0xFF) : 255
  }

  /// Converts any SwiftUI color, e.g. from a ColorPicker, to sRGB bytes.
  init(_ color: Color) {
    let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
    func byte(_ component: CGFloat) -> UInt8 {
      UInt8((min(max(component, 0), 1) * 255).rounded())
    }
    self.init(
      red: byte(srgb.redComponent), green: byte(srgb.greenComponent),
      blue: byte(srgb.blueComponent), alpha: byte(srgb.alphaComponent))
  }

  var hex: String {
    let rgb = String(format: "#%02X%02X%02X", red, green, blue)
    return alpha == 255 ? rgb : rgb + String(format: "%02X", alpha)
  }

  var color: Color {
    Color(
      .sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255,
      opacity: Double(alpha) / 255)
  }
}

extension HexColor: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let color = HexColor(hex: string) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid hex color: \(string)")
    }
    self = color
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(hex)
  }
}
