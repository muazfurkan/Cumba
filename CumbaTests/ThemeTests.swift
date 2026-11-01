import Foundation
import Testing

@testable import Cumba

struct HexColorTests {
  @Test(arguments: ["#1E3A8A", "1E3A8A", " #1e3a8a "])
  func parsesSixDigits(hex: String) throws {
    let color = try #require(HexColor(hex: hex))
    #expect(color.hex == "#1E3A8A")
    #expect(color.alpha == 255)
  }

  @Test func keepsAlpha() throws {
    let color = try #require(HexColor(hex: "#FF000080"))
    #expect(color.hex == "#FF000080")
    #expect(color.alpha == 0x80)
  }

  @Test(arguments: ["", "#12345", "#GGGGGG", "red", "#1234567"])
  func rejectsInvalidValues(hex: String) {
    #expect(HexColor(hex: hex) == nil)
  }
}

struct ThemeTests {
  private func decode(_ json: String) throws -> Theme {
    try JSONDecoder().decode(Theme.self, from: Data(json.utf8))
  }

  @Test func decodesTheSpecExample() throws {
    let theme = try decode(
      """
      {
        "id": "midnight", "name": "Midnight", "material": "tinted", "tint": "#1E3A8A",
        "background": "#000000", "foreground": "#FFFFFF", "secondary": "#9CA3AF",
        "accent": "#3B82F6", "cornerRadius": 22,
        "expandedSize": { "width": 640, "height": 190 }, "peekExtraWidth": 70,
        "animation": { "response": 0.42, "damping": 0.82 },
        "fontDesign": "rounded", "shadow": true
      }
      """)
    #expect(theme.material == .tinted)
    #expect(theme.tint.hex == "#1E3A8A")
    #expect(theme.spring == Theme.Spring(response: 0.42, damping: 0.82))
    #expect(theme.fontDesign == .rounded)
  }

  @Test func ignoresUnknownKeysAndFillsMissingOnes() throws {
    let theme = try decode(#"{ "id": "x", "name": "X", "sparkles": true }"#)
    let defaults = Theme(id: "x", name: "X")
    #expect(theme == defaults)
  }

  @Test func invalidValuesFallBackToDefaults() throws {
    let theme = try decode(
      #"{ "id": "x", "material": "chrome", "accent": "blue", "shadow": "yes", "fontDesign": 3 }"#
    )
    let defaults = Theme(id: "x", name: "")
    #expect(theme.material == defaults.material)
    #expect(theme.accent == defaults.accent)
    #expect(theme.shadow == defaults.shadow)
    #expect(theme.fontDesign == defaults.fontDesign)
  }

  @Test func outOfRangeNumbersAreClamped() throws {
    let theme = try decode(
      #"{ "cornerRadius": 900, "expandedSize": { "width": 10, "height": 5000 }, "animation": { "response": -1, "damping": 3 }, "textScale": 9 }"#
    )
    #expect(theme.cornerRadius == Theme.cornerRadiusRange.upperBound)
    #expect(theme.spring.response == Theme.responseRange.lowerBound)
    #expect(theme.spring.damping == Theme.dampingRange.upperBound)
    let size = try #require(theme.legacySize)
    #expect(size.width == PanelSize.widthRange.lowerBound)
    #expect(size.height == PanelSize.heightRange.upperBound)
    #expect(size.textScale == PanelSize.textScaleRange.upperBound)
  }

  @Test func readsTheSizeOfOlderThemeFilesButNeverSavesIt() throws {
    let old = try decode(
      #"{ "expandedSize": { "width": 720, "height": 220 }, "peekExtraWidth": 90 }"#)
    var expected = PanelSize()
    expected.width = 720
    expected.height = 220
    expected.indicatorWidth = 90
    #expect(old.legacySize == expected)
    let object = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    #expect(object["expandedSize"] == nil)
    #expect(object["legacySize"] == nil)
    #expect(try decode(#"{ "id": "x" }"#).legacySize == nil)
  }

  @Test func notJSONObjectFails() {
    #expect(throws: (any Error).self) { try decode("[1, 2, 3]") }
  }

  @Test(arguments: Theme.builtIns)
  func builtInsRoundTrip(theme: Theme) throws {
    let data = try JSONEncoder().encode(theme)
    #expect(try JSONDecoder().decode(Theme.self, from: data) == theme)
  }

  @Test func gradientAndGlowAreOptional() throws {
    let plain = try decode(#"{ "id": "x", "name": "X" }"#)
    #expect(plain.gradient == nil)
    #expect(plain.glow == nil)
    let object = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any])
    #expect(object["gradient"] == nil)
    #expect(object["glow"] == nil)

    let neon = try decode(##"{ "gradient": "#1C0B42", "glow": "#FF2E97" }"##)
    #expect(neon.gradient?.hex == "#1C0B42")
    #expect(neon.glow?.hex == "#FF2E97")
    let invalid = try decode(#"{ "gradient": "purple", "glow": 7 }"#)
    #expect(invalid.gradient == nil)
    #expect(invalid.glow == nil)
  }

  @Test func builtInsHaveDistinctIDsAndNames() {
    #expect(Set(Theme.builtIns.map(\.id)).count == Theme.builtIns.count)
    #expect(Set(Theme.builtIns.map(\.displayName)).count == Theme.builtIns.count)
  }

  @Test func encodesAnimationUnderTheSpecKey() throws {
    let data = try JSONEncoder().encode(Theme.midnight)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["animation"] != nil)
    #expect(object["spring"] == nil)
  }
}
