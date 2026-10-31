import Foundation
import Testing

@testable import Cumba

/// Works in a temporary folder; never touches the real Application Support.
struct AppFolderTests {
  private let base = FileManager.default.temporaryDirectory
    .appending(path: "AppFolderTests-\(UUID().uuidString)", directoryHint: .isDirectory)

  private func makeFolder(_ name: String, note: String) throws {
    let folder = base.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(note.utf8).write(to: folder.appending(path: "notes.txt"))
  }

  private func note(in name: String) -> String? {
    try? String(contentsOf: base.appending(path: "\(name)/notes.txt"), encoding: .utf8)
  }

  @Test func movesTheFolderOfTheFormerName() throws {
    defer { try? FileManager.default.removeItem(at: base) }
    try makeFolder(AppFolder.legacyName, note: "kept")
    #expect(AppFolder.migrateLegacyFolder(in: base))
    #expect(note(in: AppFolder.name) == "kept")
    #expect(note(in: AppFolder.legacyName) == nil)
  }

  @Test func leavesAnExistingFolderAlone() throws {
    defer { try? FileManager.default.removeItem(at: base) }
    try makeFolder(AppFolder.legacyName, note: "old")
    try makeFolder(AppFolder.name, note: "new")
    #expect(!AppFolder.migrateLegacyFolder(in: base))
    #expect(note(in: AppFolder.name) == "new")
    #expect(note(in: AppFolder.legacyName) == "old")
  }

  @Test func doesNothingWithoutAnOldFolder() {
    defer { try? FileManager.default.removeItem(at: base) }
    #expect(!AppFolder.migrateLegacyFolder(in: base))
    #expect(note(in: AppFolder.name) == nil)
  }
}
