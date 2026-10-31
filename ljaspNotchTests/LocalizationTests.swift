import Foundation
import Testing

/// Every string in the catalog must have a complete Turkish translation.
struct LocalizationTests {
  private struct Catalog: Decodable {
    var sourceLanguage: String
    var strings: [String: Entry]
  }

  private struct Entry: Decodable {
    var shouldTranslate: Bool?
    var localizations: [String: Localization]?
  }

  private struct Localization: Decodable {
    struct StringUnit: Decodable {
      var state: String
      var value: String
    }

    var stringUnit: StringUnit?
    // e.g. ["plural": ["one": ..., "other": ...]]
    var variations: [String: [String: Localization]]?
  }

  @Test(arguments: ["Localizable", "InfoPlist"])
  func catalogIsNotEmpty(name: String) throws {
    let catalog = try loadCatalog(name)
    #expect(catalog.sourceLanguage == "en")
    #expect(!catalog.strings.isEmpty)
  }

  @Test(arguments: ["Localizable", "InfoPlist"])
  func everyStringHasTurkishTranslation(name: String) throws {
    let catalog = try loadCatalog(name)
    let missing = catalog.strings
      .filter { _, entry in
        guard entry.shouldTranslate != false else { return false }
        guard let turkish = entry.localizations?["tr"] else { return true }
        return !isTranslated(turkish)
      }
      .keys
      .sorted()
    #expect(missing.isEmpty, "Missing Turkish translations: \(missing)")
  }

  private func isTranslated(_ localization: Localization) -> Bool {
    if let unit = localization.stringUnit {
      return unit.state == "translated" && !unit.value.isEmpty
    }
    if let variations = localization.variations {
      return variations.values.allSatisfy { $0.values.allSatisfy(isTranslated) }
    }
    return false
  }

  private func loadCatalog(_ name: String) throws -> Catalog {
    let url = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "ljaspNotch/Resources/\(name).xcstrings")
    return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
  }
}
