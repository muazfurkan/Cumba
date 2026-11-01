import AppKit
import ImageIO
import Observation
import SwiftUI

/// What you copied lately, as cards like a clipboard manager's: text, links, images and
/// files, and optionally new screenshots. Click a card to copy it again. macOS has no
/// "clipboard changed" event, so while this widget is in the panel it checks the
/// clipboard's change counter once a second (only reading the content when it changed).
/// Items that apps mark as concealed or transient, like passwords, are skipped. Nothing is
/// written to disk.
@MainActor
@Observable
final class ClipboardHistoryWidget: NotchWidget {
  static let kind = "clipboard"
  static var title: String { String(localized: "Clipboard History", comment: "Widget name") }
  static let symbol = "doc.on.clipboard"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "What you copied lately: text, links, images and files, kept in memory only",
      comment: "Widget description")
  }

  static let maxEntries = 20
  /// Images kept in memory at most, in bytes; older images go first.
  static let maxImageBytes = 120_000_000
  private static let screenshotsKey = "clipboard.includesScreenshots"

  private(set) var items: [ClipboardItem] = []
  private(set) var lastCopiedID: UUID?
  /// New screenshots are added as macOS saves them.
  private(set) var includesScreenshots: Bool
  /// The screenshot folder couldn't be read, e.g. access was denied.
  private(set) var screenshotsUnavailable = false

  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var changeCount = NSPasteboard.general.changeCount
  @ObservationIgnored private let screenshots = ScreenshotWatcher()
  @ObservationIgnored private let defaults: UserDefaults

  required init(context: WidgetContext) {
    defaults = .standard
    includesScreenshots = defaults.bool(forKey: Self.screenshotsKey)
    screenshots.onScreenshot = { [weak self] url in
      self?.record(.screenshot(url), from: nil)
    }
    if includesScreenshots {
      Task { await startScreenshots() }
    }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        self?.checkPasteboard()
      }
    }
  }

  func makeView() -> AnyView {
    AnyView(ClipboardView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(ClipboardSettingsView(widget: self))
  }

  func shutdown() {
    pollTask?.cancel()
    pollTask = nil
    screenshots.stop()
    items.removeAll()
  }

  /// Turned on from Settings, so macOS's request for folder access shows over that window.
  func setIncludesScreenshots(_ include: Bool) {
    includesScreenshots = include
    defaults.set(include, forKey: Self.screenshotsKey)
    if include {
      Task { await startScreenshots() }
    } else {
      screenshots.stop()
      screenshotsUnavailable = false
    }
  }

  private func startScreenshots() async {
    screenshotsUnavailable = !(await screenshots.start())
  }

  func copy(_ item: ClipboardItem) {
    if case .screenshot(let url) = item.content {
      Task {
        let data = await Task.detached { try? Data(contentsOf: url) }.value
        guard let data else {
          // The file is gone.
          remove(item)
          return
        }
        finishCopy(item, screenshotData: data)
      }
    } else {
      finishCopy(item, screenshotData: nil)
    }
  }

  private func finishCopy(_ item: ClipboardItem, screenshotData: Data?) {
    let pasteboard = NSPasteboard.general
    item.write(to: pasteboard, screenshotData: screenshotData)
    changeCount = pasteboard.changeCount
    items.removeAll { $0.id == item.id }
    items.insert(item, at: 0)
    lastCopiedID = item.id
  }

  func remove(_ item: ClipboardItem) {
    items.removeAll { $0.id == item.id }
  }

  func clear() {
    items.removeAll()
  }

  private func checkPasteboard() {
    let pasteboard = NSPasteboard.general
    guard pasteboard.changeCount != changeCount else { return }
    changeCount = pasteboard.changeCount
    guard let content = ClipboardItem.read(from: pasteboard) else { return }
    record(content, from: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
  }

  /// Adds something at the top, without duplicates and within the limits.
  func record(_ content: ClipboardItem.Content, from app: String?) {
    items.removeAll { $0.content == content }
    let item = ClipboardItem(content: content, appBundleID: app)
    items.insert(item, at: 0)
    if items.count > Self.maxEntries {
      items.removeLast(items.count - Self.maxEntries)
    }
    var imageBytes = items.reduce(0) { $0 + $1.imageBytes }
    while imageBytes > Self.maxImageBytes,
      let oldest = items.lastIndex(where: { $0.imageBytes > 0 })
    {
      imageBytes -= items[oldest].imageBytes
      items.remove(at: oldest)
    }
    lastCopiedID = nil
    makeThumbnail(for: item)
  }

  private func makeThumbnail(for item: ClipboardItem) {
    let source: @Sendable () -> CGImageSource?
    switch item.content {
    case .image(let data, _):
      source = { CGImageSourceCreateWithData(data as CFData, nil) }
    case .screenshot(let url):
      source = { CGImageSourceCreateWithURL(url as CFURL, nil) }
    default:
      return
    }
    Task {
      let made = await Task.detached { source().flatMap { ClipboardItem.thumbnail(of: $0) } }.value
      guard let made, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
      items[index].thumbnail = made.0
      items[index].pixelSize = made.1
    }
  }
}
