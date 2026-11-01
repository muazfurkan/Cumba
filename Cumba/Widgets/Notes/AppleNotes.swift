import AppKit

/// A note in Apple Notes, as the Notes widget lists it.
struct AppleNote: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let folder: String
  let modified: Date
  /// The text after the title, on one line.
  var preview = ""
}

/// Apple Notes through AppleScript, the only public way in. Lists recent notes, opens one in
/// Notes and makes new ones. Existing notes are never changed: setting a note's body through
/// AppleScript would drop its checklists and attachments.
enum AppleNotes {
  static let bundleID = "com.apple.Notes"

  /// The field and record separators in script output; they can't appear in note titles.
  private static let fieldSeparator: Character = "\u{1F}"
  private static let recordSeparator: Character = "\u{1E}"
  /// Names of the Recently Deleted folder, whose notes are left out.
  private static let deletedFolders = ["Recently Deleted", "Son Silinenler"]

  /// Starts Notes without bringing it forward, so its notes can be read.
  @MainActor
  static func launchHidden() async -> Bool {
    if AppleScriptRunner.isRunning(bundleID) {
      return true
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      return false
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.hides = true
    configuration.addsToRecentItems = false
    do {
      _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
      return true
    } catch {
      Log.widgets.error("Notes didn't start: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  /// The most recently changed notes of the default account, newest first, with previews.
  static func recent(limit: Int) async throws(AppleScriptRunner.Failure) -> [AppleNote] {
    let names = deletedFolders.map { "\"\($0)\"" }.joined(separator: ", ")
    let list = """
      tell application id "\(bundleID)"
        set fieldSep to character id 31
        set recordSep to character id 30
        set output to ""
        repeat with f in folders of default account
          set folderName to name of f
          if folderName is not in {\(names)} then
            set noteIDs to id of every note of f
            set noteNames to name of every note of f
            set noteDates to modification date of every note of f
            repeat with i from 1 to count of noteIDs
              set stamp to (item i of noteDates) as «class isot» as string
              set output to output & (item i of noteIDs) & fieldSep & folderName & fieldSep & ¬
                stamp & fieldSep & (item i of noteNames) & recordSep
            end repeat
          end if
        end repeat
        return output
      end tell
      """
    let output = try await AppleScriptRunner.shared.run(list, in: bundleID) {
      $0.stringValue ?? ""
    }
    let notes = Array(parseList(output).prefix(limit))
    guard !notes.isEmpty else { return [] }
    let texts = try await AppleScriptRunner.shared.run(
      previewScript(ids: notes.map(\.id)), in: bundleID
    ) {
      $0.stringValue ?? ""
    }
    let previews = parsePreviews(texts)
    return notes.map { note in
      var note = note
      note.preview = previews[note.id] ?? ""
      return note
    }
  }

  /// Shows a note in Notes and brings Notes forward.
  static func open(_ id: String) async throws(AppleScriptRunner.Failure) {
    let source = """
      tell application id "\(bundleID)"
        show note id "\(escaped(id))"
        activate
      end tell
      """
    try await AppleScriptRunner.shared.run(source, in: bundleID) { _ in () }
  }

  /// Makes a new note in the default folder; its first line becomes the title.
  static func create(_ text: String) async throws(AppleScriptRunner.Failure) {
    let source = """
      tell application id "\(bundleID)"
        make new note with properties {body:"\(escaped(html(for: text)))"}
      end tell
      """
    try await AppleScriptRunner.shared.run(source, in: bundleID) { _ in () }
  }

  // MARK: - Pure helpers

  /// Notes from the list script's output, newest first.
  static func parseList(_ output: String) -> [AppleNote] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return output.split(separator: recordSeparator).compactMap { record in
      let fields = record.split(separator: fieldSeparator, omittingEmptySubsequences: false)
      guard fields.count >= 4, let date = formatter.date(from: String(fields[2])) else {
        return nil
      }
      let title = fields[3...].joined(separator: " ").trimmingCharacters(
        in: .whitespacesAndNewlines)
      return AppleNote(
        id: String(fields[0]), title: title, folder: String(fields[1]), modified: date)
    }
    .sorted { $0.modified > $1.modified }
  }

  /// Each note's text after its first line, on one line, from the preview script's output.
  static func parsePreviews(_ output: String) -> [String: String] {
    var previews: [String: String] = [:]
    for record in output.split(separator: recordSeparator) {
      let fields = record.split(
        separator: fieldSeparator, maxSplits: 1, omittingEmptySubsequences: false)
      guard fields.count == 2 else { continue }
      let lines = fields[1].split(whereSeparator: \.isNewline).map {
        $0.trimmingCharacters(in: .whitespaces)
      }.filter { !$0.isEmpty }
      previews[String(fields[0])] = lines.dropFirst().joined(separator: " ")
    }
    return previews
  }

  /// A note body: the first line as the title, every other line as its own paragraph.
  static func html(for text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { line in
        let escaped = line.replacingOccurrences(of: "&", with: "&amp;")
          .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        return "<div>\(escaped.isEmpty ? "<br>" : escaped)</div>"
      }
      .joined()
  }

  /// Text inside an AppleScript string literal.
  static func escaped(_ text: String) -> String {
    text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
  }

  private static func previewScript(ids: [String]) -> String {
    let list = ids.map { "\"\(escaped($0))\"" }.joined(separator: ", ")
    return """
      tell application id "\(bundleID)"
        set output to ""
        repeat with noteID in {\(list)}
          set noteText to plaintext of note id noteID
          if length of noteText > 400 then set noteText to text 1 thru 400 of noteText
          set output to output & noteID & (character id 31) & noteText & (character id 30)
        end repeat
        return output
      end tell
      """
  }
}
