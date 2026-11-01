import Observation
import SwiftUI

/// A quick note in the panel, saved as plain text in
/// `~/Library/Application Support/Cumba/notes.txt`. It reads like Apple Notes: the first
/// line as the title, the rest below it and when it was last changed. Click it to type; the
/// panel stays open while you type and Escape closes it.
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
        lastEdited = Date()
        scheduleSave()
      }
    }
  }
  /// When the note last changed; from the file until it's edited here.
  private(set) var lastEdited: Date?

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
    let (saved, modified) = await Task.detached { () -> (String?, Date?) in
      let text = try? String(contentsOf: url, encoding: .utf8)
      let attributes = try? FileManager.default.attributesOfItem(
        atPath: url.path(percentEncoded: false))
      return (text, attributes?[.modificationDate] as? Date)
    }.value
    if let saved, text.isEmpty {
      text = saved
      lastEdited = modified
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
        // Only this user may read it. (Data protection classes fail with EPERM on macOS
        // 26.6, so the note was never saved with `.completeFileProtection`.)
        try Data(snapshot.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
      } catch {
        Log.widgets.error(
          "Saving notes failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}

/// The note like an Apple Notes widget: a yellow header with when it last changed, the
/// first line in bold and the rest in gray. Clicking it opens it for typing.
private struct NotesView: View {
  @Bindable var widget: NotesWidget
  @State private var isEditing = false
  @FocusState private var isFocused: Bool

  private var lines: (title: String, body: String) {
    let trimmed = widget.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let end = trimmed.firstIndex(of: "\n") else { return (trimmed, "") }
    return (
      String(trimmed[..<end]),
      trimmed[end...].trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        WidgetHeader("Notes", symbol: "note.text", color: .yellow) {
          if let edited = widget.lastEdited, !widget.text.isEmpty {
            Text(Self.when(edited))
          }
        }
        if isEditing {
          editor
        } else {
          preview
        }
      }
    }
  }

  private var editor: some View {
    TextEditor(text: $widget.text)
      .panelFont(.callout)
      .tint(.yellow)
      .scrollContentBackground(.hidden)
      .scrollIndicators(.never)
      .focused($isFocused)
      .onAppear { isFocused = true }
      .onChange(of: isFocused) { _, focused in
        if !focused {
          isEditing = false
        }
      }
      .onExitCommand {
        isEditing = false
        widget.closePanel()
      }
      .accessibilityLabel(Text("Notes"))
  }

  private var preview: some View {
    Button {
      isEditing = true
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        if widget.text.isEmpty {
          Text("Click to write something down…")
            .panelFont(.callout)
            .foregroundStyle(.tertiary)
        } else {
          Text(verbatim: lines.title)
            .panelFont(.headline)
            .lineLimit(1)
          if !lines.body.isEmpty {
            Text(verbatim: lines.body)
              .panelFont(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(Text("Click to edit"))
    .accessibilityLabel(Text("Notes"))
    .accessibilityValue(Text(verbatim: widget.text))
  }

  /// The time for today, the day and month before that, like Apple Notes.
  private static func when(_ date: Date) -> String {
    Calendar.current.isDateInToday(date)
      ? date.formatted(date: .omitted, time: .shortened)
      : date.formatted(.dateTime.day().month(.abbreviated))
  }
}
