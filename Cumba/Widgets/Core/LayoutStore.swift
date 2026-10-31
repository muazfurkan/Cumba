import Foundation
import Observation

/// The widget layout and its file. Edits apply at once and are saved shortly after,
/// off the main thread.
@MainActor
@Observable
final class LayoutStore {
  private(set) var layout = WidgetLayout(tabs: [])

  @ObservationIgnored private let fileURL: URL
  @ObservationIgnored private let knownKinds: [(kind: String, units: Int)]
  @ObservationIgnored private let defaultKinds: Set<String>?
  @ObservationIgnored private var saveTask: Task<Void, Never>?

  /// `~/Library/Application Support/Cumba/layout.json`
  static var standardURL: URL {
    AppFolder.url.appending(path: "layout.json")
  }

  /// - Parameters:
  ///   - knownKinds: Widget kinds of this app version with their width in units, in
  ///     default order.
  ///   - defaultKinds: Kinds placed automatically; `nil` places every new kind.
  init(
    fileURL: URL = LayoutStore.standardURL, knownKinds: [(kind: String, units: Int)],
    defaultKinds: Set<String>? = nil
  ) {
    self.fileURL = fileURL
    self.knownKinds = knownKinds
    self.defaultKinds = defaultKinds
  }

  func load() async {
    let url = fileURL
    let saved = await Task.detached { () -> WidgetLayout? in
      guard let data = try? Data(contentsOf: url) else { return nil }
      do {
        return try JSONDecoder().decode(WidgetLayout.self, from: data)
      } catch {
        Log.widgets.error(
          "layout.json is unreadable: \(error.localizedDescription, privacy: .public)")
        return nil
      }
    }.value
    var layout = saved ?? WidgetLayout(tabs: [])
    layout.removeUnknown(knownKinds: knownKinds.map(\.kind))
    layout.adoptNewKinds(knownKinds, defaults: defaultKinds)
    apply(layout, save: layout != saved)
  }

  // MARK: - Edits

  func add(_ kind: String, to tabID: String) {
    edit { layout in
      guard !layout.contains(kind), let index = layout.tabs.firstIndex(where: { $0.id == tabID })
      else { return }
      layout.tabs[index].widgets.append(kind)
    }
  }

  /// Adds a kind to the first tab with room (or a new tab), e.g. once its feature is set up.
  func addAnywhere(_ kind: String) {
    let widths = Dictionary(
      knownKinds.map { ($0.kind, $0.units) }, uniquingKeysWith: { first, _ in first })
    edit { layout in
      layout.place(kind, units: widths[kind] ?? 1, widths: widths)
    }
  }

  func remove(_ kind: String) {
    edit { layout in
      for index in layout.tabs.indices {
        layout.tabs[index].widgets.removeAll { $0 == kind }
      }
    }
  }

  func moveWidgets(in tabID: String, from source: IndexSet, to destination: Int) {
    edit { layout in
      guard let index = layout.tabs.firstIndex(where: { $0.id == tabID }) else { return }
      layout.tabs[index].widgets.move(fromOffsets: source, toOffset: destination)
    }
  }

  @discardableResult
  func addTab(title: String) -> String {
    let id = "tab-" + UUID().uuidString.prefix(8).lowercased()
    edit { layout in
      layout.tabs.append(.init(id: id, title: title, symbol: "star", widgets: []))
    }
    return id
  }

  /// Removes a tab; its widgets move to the first remaining tab. The last tab stays.
  func removeTab(_ tabID: String) {
    edit { layout in
      guard layout.tabs.count > 1, let index = layout.tabs.firstIndex(where: { $0.id == tabID })
      else { return }
      let widgets = layout.tabs.remove(at: index).widgets
      layout.tabs[0].widgets.append(contentsOf: widgets)
    }
  }

  func updateTab(_ tabID: String, title: String? = nil, symbol: String? = nil) {
    edit { layout in
      guard let index = layout.tabs.firstIndex(where: { $0.id == tabID }) else { return }
      if let title {
        layout.tabs[index].title = title
      }
      if let symbol {
        layout.tabs[index].symbol = symbol
      }
    }
  }

  func moveTabs(from source: IndexSet, to destination: Int) {
    edit { layout in
      layout.tabs.move(fromOffsets: source, toOffset: destination)
    }
  }

  // MARK: - Saving

  private func edit(_ change: (inout WidgetLayout) -> Void) {
    var copy = layout
    change(&copy)
    guard copy != layout else { return }
    apply(copy, save: true)
  }

  private func apply(_ newLayout: WidgetLayout, save: Bool) {
    layout = newLayout
    guard save else { return }
    saveTask?.cancel()
    let url = fileURL
    let snapshot = newLayout
    saveTask = Task {
      do {
        try await Task.sleep(for: .milliseconds(300))
        try await Task.detached {
          try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
          try encoder.encode(snapshot).write(to: url, options: .atomic)
        }.value
      } catch is CancellationError {
        return
      } catch {
        Log.widgets.error(
          "Saving layout.json failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
