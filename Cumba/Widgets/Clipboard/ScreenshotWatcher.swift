import Foundation

/// New screenshots in the folder macOS saves them to, from file system events (no polling).
/// Only files macOS marks as screen captures count, and only images, not recordings.
@MainActor
final class ScreenshotWatcher {
  var onScreenshot: ((URL) -> Void)?

  private var source: DispatchSourceFileSystemObject?
  private var known: Set<String> = []
  private var folder: URL?

  nonisolated private static let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "heic", "tiff",
  ]

  /// Where macOS saves screenshots: the folder chosen in the Screenshot app, else Desktop.
  static var folder: URL {
    let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
    if let path, !path.isEmpty {
      return URL(filePath: (path as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appending(
      path: "Desktop", directoryHint: .isDirectory)
  }

  var isRunning: Bool { source != nil }

  /// Starts watching. Returns false when the folder can't be read, e.g. access was denied;
  /// macOS asks for access to Desktop the first time.
  @discardableResult
  func start() async -> Bool {
    stop()
    let folder = Self.folder
    let names = await Task.detached { Self.names(in: folder) }.value
    guard let names else {
      Log.widgets.error("The screenshot folder can't be read")
      return false
    }
    let descriptor = open(folder.path(percentEncoded: false), O_EVTONLY)
    guard descriptor >= 0 else {
      Log.widgets.error("The screenshot folder can't be watched")
      return false
    }
    known = names
    self.folder = folder
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: .write, queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.folderChanged() }
    }
    source.setCancelHandler { close(descriptor) }
    source.resume()
    self.source = source
    return true
  }

  func stop() {
    source?.cancel()
    source = nil
    folder = nil
    known = []
  }

  private func folderChanged() {
    guard let folder else { return }
    let known = known
    Task {
      // macOS writes the file under a hidden name first and renames it a moment later.
      try? await Task.sleep(for: .milliseconds(600))
      let found = await Task.detached { Self.screenshots(in: folder, excluding: known) }.value
      guard self.folder == folder else { return }
      for url in found where !self.known.contains(url.lastPathComponent) {
        self.known.insert(url.lastPathComponent)
        onScreenshot?(url)
      }
    }
  }

  nonisolated private static func names(in folder: URL) -> Set<String>? {
    guard
      let names = try? FileManager.default.contentsOfDirectory(
        atPath: folder.path(percentEncoded: false))
    else { return nil }
    return Set(names)
  }

  /// Screenshots in the folder that aren't among `known`, oldest first. Reads the folder.
  nonisolated static func screenshots(in folder: URL, excluding known: Set<String>) -> [URL] {
    let urls =
      (try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: [.creationDateKey],
        options: [.skipsHiddenFiles])) ?? []
    return
      urls
      .filter {
        !known.contains($0.lastPathComponent)
          && imageExtensions.contains($0.pathExtension.lowercased()) && isScreenCapture($0)
      }
      .sorted { creationDate($0) < creationDate($1) }
  }

  /// macOS marks its screenshots with this extended attribute.
  nonisolated static func isScreenCapture(_ url: URL) -> Bool {
    getxattr(
      url.path(percentEncoded: false), "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0)
      > 0
  }

  nonisolated private static func creationDate(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
  }
}
