import Foundation

/// Reads and writes user themes as JSON files. Every method does file I/O, so call them
/// off the main thread.
struct ThemeFiles: Sendable {
  let directory: URL

  /// `~/Library/Application Support/Cumba/Themes`
  static var standard: ThemeFiles {
    ThemeFiles(directory: AppFolder.url.appending(path: "Themes", directoryHint: .isDirectory))
  }

  /// Loads every readable theme. Broken files are skipped and logged, never fatal.
  func loadAll() -> [Theme] {
    let urls =
      (try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)) ?? []
    return
      urls
      .filter { $0.pathExtension.lowercased() == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
      .compactMap { url in
        do {
          var theme = try read(url)
          // The file name is the id; it wins over whatever the file says.
          theme.id = url.deletingPathExtension().lastPathComponent
          return theme
        } catch {
          Log.theme.error(
            "Skipping theme \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
          )
          return nil
        }
      }
  }

  func read(_ url: URL) throws -> Theme {
    try JSONDecoder().decode(Theme.self, from: Data(contentsOf: url))
  }

  func save(_ theme: Theme) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try write(theme, to: url(for: theme.id))
  }

  func delete(id: String) throws {
    let url = url(for: id)
    if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
      try FileManager.default.removeItem(at: url)
    }
  }

  func write(_ theme: Theme, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(theme).write(to: url, options: .atomic)
  }

  private func url(for id: String) -> URL {
    directory.appending(path: "\(id).json")
  }
}
