/// Themes that ship with the app. They can't be edited, only duplicated.
extension Theme {
  static let classic: Theme = {
    var theme = Theme(id: "classic", name: "Classic")
    theme.material = .solid
    return theme
  }()

  static let glass: Theme = {
    var theme = Theme(id: "glass", name: "Glass")
    theme.material = .glass
    theme.cornerRadius = 28
    theme.fontDesign = .rounded
    return theme
  }()

  static let midnight: Theme = {
    var theme = Theme(id: "midnight", name: "Midnight")
    theme.material = .tinted
    theme.tint = HexColor(red: 0x1E, green: 0x3A, blue: 0x8A)
    theme.accent = HexColor(red: 0x3B, green: 0x82, blue: 0xF6)
    theme.cornerRadius = 22
    theme.spring = Spring(response: 0.42, damping: 0.86)
    theme.fontDesign = .rounded
    return theme
  }()

  /// Night-time Tokyo signs: deep indigo, a pink to cyan neon edge, monospaced text.
  static let neonTokyo: Theme = {
    var theme = Theme(id: "neon-tokyo", name: "Neon Tokyo")
    theme.background = HexColor(red: 0x07, green: 0x05, blue: 0x12)
    theme.gradient = HexColor(red: 0x1C, green: 0x0B, blue: 0x42)
    theme.foreground = HexColor(red: 0xE9, green: 0xFB, blue: 0xFF)
    theme.secondary = HexColor(red: 0x8E, green: 0x93, blue: 0xC4)
    theme.accent = HexColor(red: 0x00, green: 0xE5, blue: 0xFF)
    theme.glow = HexColor(red: 0xFF, green: 0x2E, blue: 0x97)
    theme.cornerRadius = 16
    theme.spring = Spring(response: 0.32, damping: 0.9)
    theme.fontDesign = .monospaced
    theme.textScale = 1.1
    return theme
  }()

  /// Cherry blossom pink on dark plum, soft and rounded.
  static let sakura: Theme = {
    var theme = Theme(id: "sakura", name: "Sakura")
    theme.background = HexColor(red: 0x0E, green: 0x08, blue: 0x0B)
    theme.gradient = HexColor(red: 0x2E, green: 0x15, blue: 0x22)
    theme.foreground = HexColor(red: 0xFF, green: 0xF1, blue: 0xF5)
    theme.secondary = HexColor(red: 0xC9, green: 0xA3, blue: 0xB4)
    theme.accent = HexColor(red: 0xFF, green: 0x8F, blue: 0xB8)
    theme.glow = HexColor(red: 0xFF, green: 0xC4, blue: 0xD8)
    theme.cornerRadius = 30
    theme.spring = Spring(response: 0.42, damping: 0.85)
    theme.fontDesign = .rounded
    return theme
  }()

  /// An eighties sunset: violet into magenta, with an orange accent.
  static let synthwave: Theme = {
    var theme = Theme(id: "synthwave", name: "Synthwave")
    theme.background = HexColor(red: 0x0B, green: 0x02, blue: 0x1C)
    theme.gradient = HexColor(red: 0x4A, green: 0x0E, blue: 0x4E)
    theme.foreground = HexColor(red: 0xFF, green: 0xF4, blue: 0xE0)
    theme.secondary = HexColor(red: 0xC0, green: 0x9C, blue: 0xD8)
    theme.accent = HexColor(red: 0xFF, green: 0x9E, blue: 0x3D)
    theme.glow = HexColor(red: 0xFF, green: 0x2B, blue: 0xD6)
    theme.cornerRadius = 22
    theme.spring = Spring(response: 0.38, damping: 0.88)
    return theme
  }()

  /// The calm dark of a code editor at night, with violet and pink.
  static let violetNight: Theme = {
    var theme = Theme(id: "violet-night", name: "Violet Night")
    theme.background = HexColor(red: 0x14, green: 0x13, blue: 0x1C)
    theme.gradient = HexColor(red: 0x24, green: 0x21, blue: 0x35)
    theme.foreground = HexColor(red: 0xF6, green: 0xF5, blue: 0xF0)
    theme.secondary = HexColor(red: 0x8A, green: 0x90, blue: 0xB8)
    theme.accent = HexColor(red: 0xC4, green: 0x9B, blue: 0xFF)
    theme.glow = HexColor(red: 0xFF, green: 0x7A, blue: 0xC8)
    theme.cornerRadius = 22
    theme.fontDesign = .rounded
    return theme
  }()

  static let builtIns = [classic, glass, midnight, neonTokyo, sakura, synthwave, violetNight]
}
