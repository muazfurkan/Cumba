import Foundation
import Testing

@testable import Cumba

/// Uses a temporary directory and defaults suite; never touches the real theme folder.
@MainActor
struct ThemeStoreTests {
  private let directory = FileManager.default.temporaryDirectory
    .appending(path: "ThemeStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  private let suiteName = "ThemeStoreTests-\(UUID().uuidString)"

  private func makeStore() throws -> ThemeStore {
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    return ThemeStore(files: ThemeFiles(directory: directory), defaults: defaults)
  }

  private func cleanUp() {
    try? FileManager.default.removeItem(at: directory)
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }

  @Test func startsWithClassic() throws {
    defer { cleanUp() }
    let store = try makeStore()
    #expect(store.current == .classic)
    #expect(store.themes.count == Theme.builtIns.count)
  }

  @Test func builtInThemesKeepTheirNamesAndUserThemesTakeAnyName() async throws {
    defer { cleanUp() }
    let store = try makeStore()
    var renamed = Theme.neonTokyo
    renamed.name = "Mine"
    renamed.cornerRadius += 4
    store.update(renamed)
    // The change is kept, the name isn't, and no new theme appears.
    #expect(store.userThemes.isEmpty)
    let changed = try #require(store.themes.first { $0.id == Theme.neonTokyo.id })
    #expect(changed.cornerRadius == Theme.neonTokyo.cornerRadius + 4)
    #expect(changed.name == Theme.neonTokyo.name)
    #expect(store.isChanged(changed))
    try await Task.sleep(for: .milliseconds(800))
    let reloaded = try makeStore()
    await reloaded.load()
    #expect(reloaded.themes.first { $0.id == Theme.neonTokyo.id } == changed)
    #expect(reloaded.userThemes.isEmpty)
    reloaded.restoreDefaults(changed)
    #expect(reloaded.themes.contains(.neonTokyo))
    #expect(!reloaded.isChanged(.neonTokyo))

    let copy = store.duplicate(.neonTokyo, name: "Gece Mavisi")
    #expect(store.current.id == copy.id)
    #expect(store.current.glow == Theme.neonTokyo.glow)
    var edited = store.current
    edited.name = "Tokyo Gecesi"
    store.update(edited)
    #expect(store.current.displayName == "Tokyo Gecesi")
    edited.name = ""
    store.update(edited)
    #expect(store.current.displayName.isEmpty == false)
    #expect(Theme.neonTokyo.displayName == String(localized: "Neon Tokyo"))
  }

  @Test func corruptFilesAreSkipped() async throws {
    defer { cleanUp() }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: directory.appending(path: "broken.json"))
    try ThemeFiles(directory: directory).save(Theme(id: "good", name: "Good"))

    let store = try makeStore()
    await store.load()
    #expect(store.userThemes.map(\.id) == ["good"])
  }

  @Test func duplicateIsSavedAndSelected() async throws {
    defer { cleanUp() }
    let store = try makeStore()
    let copy = store.duplicate(.midnight, name: "Mine")
    #expect(store.current == copy)
    #expect(!store.isBuiltIn(copy))

    // The save runs in the background; wait for the file.
    let file = directory.appending(path: "\(copy.id).json")
    for _ in 0..<50 where !FileManager.default.fileExists(atPath: file.path()) {
      try await Task.sleep(for: .milliseconds(20))
    }
    let reloaded = try makeStore()
    await reloaded.load()
    #expect(reloaded.userThemes.map(\.name) == ["Mine"])
    #expect(reloaded.current.id == copy.id)
  }

  @Test func updatesAreNormalized() throws {
    defer { cleanUp() }
    let store = try makeStore()
    var theme = store.duplicate(.classic, name: "Big")
    theme.cornerRadius = 500
    store.update(theme)
    #expect(store.current.cornerRadius == Theme.cornerRadiusRange.upperBound)
  }

  @Test func deletingTheSelectedThemeFallsBackToClassic() throws {
    defer { cleanUp() }
    let store = try makeStore()
    let copy = store.duplicate(.glass, name: "Temp")
    store.delete(copy)
    #expect(store.current == .classic)
    #expect(store.userThemes.isEmpty)
  }

  @Test func builtInsCannotBeDeleted() throws {
    defer { cleanUp() }
    let store = try makeStore()
    store.delete(.glass)
    #expect(store.themes.contains(.glass))
  }
}
