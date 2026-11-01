import Observation
import SwiftUI

/// Buttons for favorite Shortcuts, run with the `shortcuts` command line tool. The name is
/// passed as an argument, never through a shell.
@MainActor
@Observable
final class ShortcutsWidget: NotchWidget {
  static let kind = "shortcuts"
  static var title: String { String(localized: "Shortcuts", comment: "Widget name") }
  static let symbol = "square.stack.3d.up"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "Run your favorite shortcuts", comment: "Widget description")
  }

  static let maxFavorites = 6
  private static let favoritesKey = "shortcuts.favorites"
  private nonisolated static let tool = URL(filePath: "/usr/bin/shortcuts")

  private(set) var favorites: [String]
  private(set) var available: [String] = []
  private(set) var running: Set<String> = []
  private(set) var failed: String?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let openSettings: @MainActor (SettingsPage) -> Void

  required convenience init(context: WidgetContext) {
    self.init(defaults: .standard, openSettings: context.openSettings)
  }

  init(
    defaults: UserDefaults,
    openSettings: @escaping @MainActor (SettingsPage) -> Void
  ) {
    self.defaults = defaults
    self.openSettings = openSettings
    favorites = defaults.stringArray(forKey: Self.favoritesKey) ?? []
  }

  func makeView() -> AnyView {
    AnyView(ShortcutsView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(ShortcutsSettingsView(widget: self))
  }

  /// A name starting with "-" would be read as an option by the command line tool.
  nonisolated static func isRunnable(_ name: String) -> Bool {
    !name.isEmpty && !name.hasPrefix("-")
  }

  func toggleFavorite(_ name: String) {
    guard Self.isRunnable(name) else { return }
    if let index = favorites.firstIndex(of: name) {
      favorites.remove(at: index)
    } else if favorites.count < Self.maxFavorites {
      favorites.append(name)
    }
    defaults.set(favorites, forKey: Self.favoritesKey)
  }

  func loadAvailable() async {
    do {
      let output = try await Self.runTool(["list"])
      available = Self.parseList(output).filter(Self.isRunnable)
    } catch {
      Log.widgets.error("Listing shortcuts failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func run(_ name: String) {
    guard Self.isRunnable(name), !running.contains(name) else { return }
    running.insert(name)
    failed = nil
    Task {
      do {
        _ = try await Self.runTool(["run", name])
      } catch {
        failed = name
      }
      running.remove(name)
    }
  }

  func showSettings() {
    openSettings(.widget(Self.kind))
  }

  /// One shortcut name per line.
  nonisolated static func parseList(_ output: String) -> [String] {
    var seen = Set<String>()
    return output.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  /// Runs `/usr/bin/shortcuts` off the main thread and returns its standard output.
  nonisolated static func runTool(_ arguments: [String]) async throws -> String {
    try await Task.detached {
      let process = Process()
      process.executableURL = tool
      process.arguments = arguments
      let output = Pipe()
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else {
        throw CocoaError(.executableLoad)
      }
      return String(decoding: data, as: UTF8.self)
    }.value
  }
}

private struct ShortcutsView: View {
  let widget: ShortcutsWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        WidgetHeader("Shortcuts", symbol: "square.stack.3d.up", color: .pink)
        if widget.favorites.isEmpty {
          Button("Choose Shortcuts") { widget.showSettings() }
            .controlSize(.small)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
            ForEach(widget.favorites, id: \.self) { name in
              Button {
                widget.run(name)
              } label: {
                HStack(spacing: 4) {
                  if widget.running.contains(name) {
                    ProgressView().controlSize(.mini)
                  }
                  Text(name).lineLimit(1)
                }
                .panelFont(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                  widget.failed == name ? .red.opacity(0.3) : .white.opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }
}

private struct ShortcutsSettingsView: View {
  let widget: ShortcutsWidget

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Pick up to \(ShortcutsWidget.maxFavorites) shortcuts to show in the panel.")
        .foregroundStyle(.secondary)
      if widget.available.isEmpty {
        Text("No shortcuts found.")
          .foregroundStyle(.secondary)
      }
      ForEach(widget.available, id: \.self) { name in
        Toggle(
          name,
          isOn: Binding(
            get: { widget.favorites.contains(name) },
            set: { _ in widget.toggleFavorite(name) }))
      }
    }
    .task { await widget.loadAvailable() }
  }
}
