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

  static let builtIns = [classic, glass, midnight]
}
