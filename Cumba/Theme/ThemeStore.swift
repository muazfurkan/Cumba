import Foundation
import Observation

/// Built-in and user themes, and which one is active. Built-in themes keep their names but
/// can be changed; the change is saved under the built-in's id and can be undone with
/// `restoreDefaults`. File I/O runs off the main thread.
@MainActor
@Observable
final class ThemeStore {
  private(set) var userThemes: [Theme] = []
  /// The user's changes to built-in themes, by the built-in's id.
  private(set) var changedBuiltIns: [String: Theme] = [:]
  private(set) var selectedID: String

  @ObservationIgnored private let files: ThemeFiles
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]

  private static let selectedKey = "selectedThemeID"

  init(files: ThemeFiles = .standard, defaults: UserDefaults = .standard) {
    self.files = files
    self.defaults = defaults
    selectedID = defaults.string(forKey: Self.selectedKey) ?? Theme.classic.id
  }

  var themes: [Theme] { Theme.builtIns.map { changedBuiltIns[$0.id] ?? $0 } + userThemes }

  var current: Theme {
    themes.first { $0.id == selectedID } ?? .classic
  }

  func isBuiltIn(_ theme: Theme) -> Bool {
    Theme.builtIns.contains { $0.id == theme.id }
  }

  /// Whether a built-in theme has the user's changes.
  func isChanged(_ theme: Theme) -> Bool {
    changedBuiltIns[theme.id] != nil
  }

  func load() async {
    let files = files
    let loaded = await Task.detached { files.loadAll() }.value
    let builtInIDs = Set(Theme.builtIns.map(\.id))
    userThemes = loaded.filter { !builtInIDs.contains($0.id) }
    changedBuiltIns = Dictionary(
      loaded.filter { builtInIDs.contains($0.id) }.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
  }

  func select(_ id: String) {
    selectedID = id
    defaults.set(id, forKey: Self.selectedKey)
  }

  /// Copies a theme into a new, editable user theme and selects it.
  @discardableResult
  func duplicate(_ theme: Theme, name: String) -> Theme {
    var copy = theme
    copy.id = Self.newID()
    copy.name = name
    userThemes.append(copy)
    scheduleSave(copy, after: .zero)
    select(copy.id)
    return copy
  }

  /// Applies an edit right away (the panel previews it live) and saves it shortly after,
  /// so dragging a slider doesn't write a file for every step.
  func update(_ theme: Theme) {
    if let builtIn = Theme.builtIns.first(where: { $0.id == theme.id }) {
      var changed = theme.normalized()
      changed.name = builtIn.name
      changedBuiltIns[theme.id] = changed
      scheduleSave(changed, after: .milliseconds(500))
      return
    }
    guard let index = userThemes.firstIndex(where: { $0.id == theme.id }) else { return }
    userThemes[index] = theme.normalized()
    scheduleSave(userThemes[index], after: .milliseconds(500))
  }

  /// Takes back the user's changes to a built-in theme.
  func restoreDefaults(_ theme: Theme) {
    guard changedBuiltIns.removeValue(forKey: theme.id) != nil else { return }
    removeFile(of: theme.id)
  }

  func delete(_ theme: Theme) {
    guard !isBuiltIn(theme) else { return }
    userThemes.removeAll { $0.id == theme.id }
    if selectedID == theme.id {
      select(Theme.classic.id)
    }
    removeFile(of: theme.id)
  }

  private func removeFile(of id: String) {
    saveTasks[id]?.cancel()
    saveTasks[id] = nil
    let files = files
    Task.detached {
      do {
        try files.delete(id: id)
      } catch {
        Log.theme.error("Deleting theme failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  /// Imports a theme file as a new user theme and selects it.
  func importTheme(from url: URL) async throws {
    let files = files
    var theme = try await Task.detached { try files.read(url) }.value
    theme.id = Self.newID()
    if theme.name.isEmpty {
      theme.name = url.deletingPathExtension().lastPathComponent
    }
    userThemes.append(theme)
    scheduleSave(theme, after: .zero)
    select(theme.id)
  }

  func export(_ theme: Theme, to url: URL) async throws {
    let files = files
    try await Task.detached { try files.write(theme, to: url) }.value
  }

  private func scheduleSave(_ theme: Theme, after delay: Duration) {
    saveTasks[theme.id]?.cancel()
    let files = files
    saveTasks[theme.id] = Task {
      do {
        try await Task.sleep(for: delay)
        try await Task.detached { try files.save(theme) }.value
      } catch is CancellationError {
        return
      } catch {
        Log.theme.error("Saving theme failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private static func newID() -> String {
    "user-" + UUID().uuidString.prefix(8).lowercased()
  }
}

extension Theme {
  /// Name shown in the interface; built-in themes are translated.
  var displayName: String {
    switch id {
    case Theme.classic.id: String(localized: "Classic", comment: "Built-in theme name")
    case Theme.glass.id: String(localized: "Glass", comment: "Built-in theme name")
    case Theme.midnight.id: String(localized: "Midnight", comment: "Built-in theme name")
    case Theme.neonTokyo.id: String(localized: "Neon Tokyo", comment: "Built-in theme name")
    case Theme.sakura.id: String(localized: "Sakura", comment: "Built-in theme name")
    case Theme.synthwave.id: String(localized: "Synthwave", comment: "Built-in theme name")
    case Theme.violetNight.id:
      String(localized: "Violet Night", comment: "Built-in theme name")
    default:
      name.isEmpty ? String(localized: "Untitled Theme", comment: "Theme without a name") : name
    }
  }
}
