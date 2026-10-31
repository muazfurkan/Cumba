import Foundation

/// The app's folder in Application Support, for the layout, notes, themes and the hook
/// socket. Versions before the rename kept it under the app's former name.
enum AppFolder {
  static let name = "Cumba"
  static let legacyName = "ljaspNotch"

  /// `~/Library/Application Support/Cumba`
  static var url: URL {
    applicationSupport.appending(path: name, directoryHint: .isDirectory)
  }

  static var applicationSupport: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support")
  }

  /// Moves the folder of the former name to the new one, once. Does nothing when there is
  /// no old folder or the new one already exists. Returns true when it moved the folder.
  @discardableResult
  static func migrateLegacyFolder(in base: URL = applicationSupport) -> Bool {
    let fileManager = FileManager.default
    let legacy = base.appending(path: legacyName, directoryHint: .isDirectory)
    let current = base.appending(path: name, directoryHint: .isDirectory)
    guard fileManager.fileExists(atPath: legacy.path(percentEncoded: false)),
      !fileManager.fileExists(atPath: current.path(percentEncoded: false))
    else { return false }
    do {
      try fileManager.moveItem(at: legacy, to: current)
      Log.app.info("Moved the app folder from its former name")
      return true
    } catch {
      Log.app.error(
        "Moving the app folder failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }
}
