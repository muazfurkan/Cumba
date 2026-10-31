import Observation
import SwiftUI

/// A quick note in the panel, saved as plain text in
/// `~/Library/Application Support/Cumba/notes.txt`. Click into it to type; the panel
/// stays open while you type and Escape closes it.
@MainActor
@Observable
final class NotesWidget: NotchWidget {
  static let kind = "notes"
  static var title: String { String(localized: "Notes", comment: "Widget name") }
  static let symbol = "note.text"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "A quick note that's always one hover away", comment: "Widget description")
  }

  /// Longest note kept, in characters.
  static let maxLength = 20_000

  var text = "" {
    didSet {
      if text.count > Self.maxLength {
        text = String(text.prefix(Self.maxLength))
      }
      if isLoaded {
        scheduleSave()
      }
    }
  }

  @ObservationIgnored private let fileURL: URL
  @ObservationIgnored private let panel: PanelControl
  @ObservationIgnored private var isLoaded = false
  @ObservationIgnored private var saveTask: Task<Void, Never>?

  static var standardURL: URL {
    AppFolder.url.appending(path: "notes.txt")
  }

  required convenience init(context: WidgetContext) {
    self.init(fileURL: Self.standardURL, panel: context.panel)
  }

  init(fileURL: URL, panel: PanelControl) {
    self.fileURL = fileURL
    self.panel = panel
    Task { await load() }
  }

  func makeView() -> AnyView {
    AnyView(NotesView(widget: self))
  }

  func shutdown() {
    saveTask?.cancel()
    saveNow()
  }

  func closePanel() {
    panel.close()
  }

  func load() async {
    let url = fileURL
    let saved = await Task.detached { try? String(contentsOf: url, encoding: .utf8) }.value
    if let saved, text.isEmpty {
      text = saved
    }
    isLoaded = true
  }

  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch {
        return
      }
      self?.saveNow()
    }
  }

  private func saveNow() {
    let url = fileURL
    let snapshot = text
    Task.detached {
      do {
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(snapshot.utf8).write(to: url, options: [.atomic, .completeFileProtection])
      } catch {
        Log.widgets.error(
          "Saving notes failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}

private struct NotesView: View {
  @Bindable var widget: NotesWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        Label("Notes", systemImage: "note.text")
          .font(.caption)
          .foregroundStyle(.secondary)
        TextEditor(text: $widget.text)
          .font(.callout)
          .scrollContentBackground(.hidden)
          .scrollIndicators(.never)
          .overlay(alignment: .topLeading) {
            if widget.text.isEmpty {
              Text("Click to write something down…")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
          .onExitCommand { widget.closePanel() }
          .accessibilityLabel(Text("Notes"))
      }
    }
  }
}
