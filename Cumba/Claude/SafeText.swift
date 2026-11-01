import Foundation

/// Text from a hook payload made safe to show next to an Allow button. Nothing that could
/// hide part of a command survives silently: control, bidi and zero-width characters are
/// shown as `⟨U+XXXX⟩`, long runs of spaces or blank lines and stacked combining marks are
/// collapsed, and length is capped. When anything like that happened, `isSuspicious` is true
/// and the notch offers only Deny and In Terminal.
struct SafeText: Equatable, Sendable {
  let text: String
  let isSuspicious: Bool

  /// Longest text shown, in Unicode scalars.
  static let maxScalars = 4000
  /// Runs of spaces longer than this are collapsed and flagged.
  static let maxSpaceRun = 12
  /// Line breaks in a row (two blank lines); more could push the rest of a command out of
  /// the card's small box, so they're collapsed and flagged.
  static let maxLineBreaks = 3
  /// Combining marks allowed on one base character.
  static let maxCombiningMarks = 3

  init(_ raw: String) {
    var output = String.UnicodeScalarView()
    var suspicious = false
    var spaceRun = 0
    var lineBreaks = 0
    var combining = 0
    var count = 0

    func flushLineBreaks() {
      guard lineBreaks > 0 else { return }
      if lineBreaks > Self.maxLineBreaks {
        output.append(contentsOf: "\n⟨\(lineBreaks) line breaks⟩\n".unicodeScalars)
        suspicious = true
      } else {
        output.append(contentsOf: String(repeating: "\n", count: lineBreaks).unicodeScalars)
      }
      lineBreaks = 0
    }

    func flushSpaces() {
      guard spaceRun > 0 else { return }
      if spaceRun > Self.maxSpaceRun {
        output.append(contentsOf: "⟨\(spaceRun) spaces⟩".unicodeScalars)
        suspicious = true
      } else {
        output.append(contentsOf: String(repeating: " ", count: spaceRun).unicodeScalars)
      }
      spaceRun = 0
    }

    for scalar in raw.unicodeScalars {
      count += 1
      if count > Self.maxScalars {
        suspicious = true
        break
      }
      if scalar == " " {
        spaceRun += 1
        continue
      }
      if scalar == "\n" {
        // Spaces on an otherwise blank line belong to the run of line breaks.
        if lineBreaks > 0 {
          spaceRun = 0
        }
        flushSpaces()
        lineBreaks += 1
        continue
      }
      flushLineBreaks()
      flushSpaces()
      switch scalar.properties.generalCategory {
      case .nonspacingMark, .enclosingMark:
        combining += 1
        if combining > Self.maxCombiningMarks {
          suspicious = true
          continue
        }
        output.append(scalar)
        continue
      case .control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .unassigned,
        .surrogate:
        if scalar == "\t" {
          output.append(contentsOf: "⇥".unicodeScalars)
        } else {
          output.append(contentsOf: Self.escaped(scalar).unicodeScalars)
          suspicious = true
        }
      default:
        output.append(scalar)
      }
      combining = 0
    }
    // Trailing line breaks hide nothing.
    lineBreaks = min(lineBreaks, Self.maxLineBreaks)
    flushLineBreaks()
    flushSpaces()
    if count > Self.maxScalars {
      output.append(contentsOf: "\n⟨…⟩".unicodeScalars)
    }
    text = String(output)
    isSuspicious = suspicious
  }

  static func escaped(_ scalar: Unicode.Scalar) -> String {
    "⟨U+" + String(scalar.value, radix: 16, uppercase: true).leftPadded(to: 4) + "⟩"
  }
}

extension String {
  fileprivate func leftPadded(to length: Int) -> String {
    count >= length ? self : String(repeating: "0", count: length - count) + self
  }
}
