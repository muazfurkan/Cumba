import Observation
import SwiftUI

/// Your Apple Notes in the panel: the most recent notes, like Apple's Notes widget, and a
/// new note typed right here. Notes is read through AppleScript once the user connects it
/// in Settings (macOS asks for Automation access once); Cumba starts Notes in the background
/// when it isn't running. Existing notes are only opened, never changed.
@MainActor
@Observable
final class NotesWidget: NotchWidget {
  static let kind = "notes"
  static var title: String { String(localized: "Notes", comment: "Widget name") }
  static let symbol = "note.text"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "Your recent Apple Notes, and new notes typed in the panel",
      comment: "Widget description")
  }

  enum Status: Equatable {
    case notConnected
    case loading
    case ready
    /// Automation access to Notes was turned off in System Settings.
    case denied
    case failed
  }

  private(set) var notes: [AppleNote] = []
  private(set) var status: Status
  /// A new note being typed in the panel.
  var draft = ""

  @ObservationIgnored private let panel: PanelControl
  @ObservationIgnored private let openSettings: @MainActor (SettingsPage) -> Void
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let oldNoteURL: URL

  private static let connectedKey = "notes.connected"
  private static let movedOldNoteKey = "notes.movedOldNote"
  static let shownNotes = 6

  /// Where the note of earlier versions was kept; it moves to Apple Notes once.
  static var oldNoteURL: URL {
    AppFolder.url.appending(path: "notes.txt")
  }

  required convenience init(context: WidgetContext) {
    self.init(
      panel: context.panel, openSettings: context.openSettings, defaults: .standard,
      oldNoteURL: Self.oldNoteURL)
  }

  init(
    panel: PanelControl, openSettings: @escaping @MainActor (SettingsPage) -> Void,
    defaults: UserDefaults, oldNoteURL: URL
  ) {
    self.panel = panel
    self.openSettings = openSettings
    self.defaults = defaults
    self.oldNoteURL = oldNoteURL
    status = defaults.bool(forKey: Self.connectedKey) ? .loading : .notConnected
  }

  func makeView() -> AnyView {
    AnyView(NotesView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(NotesSettingsView(widget: self))
  }

  func activate() {
    Task { await refresh() }
  }

  func closePanel() {
    panel.close()
  }

  var isConnected: Bool { defaults.bool(forKey: Self.connectedKey) }

  /// Asks for Automation access to Notes. Call it from Settings, or after closing the panel,
  /// so the prompt can't end up behind the panel.
  func connect() async {
    guard await AppleNotes.launchHidden() else {
      status = .failed
      return
    }
    switch await AppleScriptRunner.shared.permission(for: AppleNotes.bundleID, ask: true) {
    case .granted:
      defaults.set(true, forKey: Self.connectedKey)
      await moveOldNote()
      await refresh()
    case .denied:
      status = .denied
    case .notDetermined:
      status = .notConnected
    }
  }

  /// From the panel: closes it first, then shows the prompt.
  func connectFromPanel() {
    panel.close()
    NSApp.activate()
    Task { await connect() }
  }

  func refresh() async {
    guard isConnected else {
      status = .notConnected
      return
    }
    if notes.isEmpty {
      status = .loading
    }
    guard await AppleNotes.launchHidden() else {
      status = .failed
      return
    }
    do {
      notes = try await AppleNotes.recent(limit: Self.shownNotes)
      status = .ready
    } catch .denied, .needsPermission {
      status = .denied
    } catch {
      Log.widgets.error("Reading Apple Notes failed")
      status = .failed
    }
  }

  func open(_ note: AppleNote) {
    Task {
      do {
        try await AppleNotes.open(note.id)
        panel.close()
      } catch {
        Log.widgets.error("Opening a note in Notes failed")
      }
    }
  }

  /// Saves what was typed as a new note in Apple Notes.
  func saveDraft() async -> Bool {
    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }
    do {
      try await AppleNotes.create(text)
      draft = ""
      await refresh()
      return true
    } catch {
      Log.widgets.error("Making a note in Notes failed")
      return false
    }
  }

  func showSettings() {
    openSettings(.widget(Self.kind))
  }

  /// The note earlier versions kept in a file becomes a note in Apple Notes, once. The file
  /// stays where it was.
  private func moveOldNote() async {
    guard !defaults.bool(forKey: Self.movedOldNoteKey) else { return }
    let url = oldNoteURL
    let text = await Task.detached { try? String(contentsOf: url, encoding: .utf8) }.value
    let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmed.isEmpty {
      do {
        try await AppleNotes.create(trimmed)
      } catch {
        Log.widgets.error("Moving the old note to Notes failed")
        return
      }
    }
    defaults.set(true, forKey: Self.movedOldNoteKey)
  }
}
