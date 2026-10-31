import Foundation
import Testing

@testable import Cumba

struct WidgetLayoutTests {
  private typealias Tab = WidgetLayout.Tab

  @Test func decodesTheSpecExample() throws {
    let json = """
      {
        "version": 1,
        "tabs": [
          { "id": "home", "title": "Home", "symbol": "house", "widgets": ["media", "calendar", "claude-code"] },
          { "id": "tray", "title": "Tray", "symbol": "tray", "widgets": ["tray"] }
        ]
      }
      """
    let layout = try JSONDecoder().decode(WidgetLayout.self, from: Data(json.utf8))
    #expect(layout.tabs.map(\.id) == ["home", "tray"])
    #expect(layout.tabs[0].widgets == ["media", "calendar", "claude-code"])
  }

  @Test func brokenTabsFallBackToEmpty() throws {
    let layout = try JSONDecoder().decode(
      WidgetLayout.self, from: Data(#"{ "tabs": "nope", "extra": 1 }"#.utf8))
    #expect(layout.tabs.isEmpty)
  }

  @Test func newInstallGetsOnlyTheDefaultWidgets() {
    var layout = WidgetLayout(tabs: [])
    let kinds = [("media", 2), ("claude-code", 2), ("calendar", 2), ("timer", 2), ("tray", 2)]
    layout.adoptNewKinds(kinds, defaults: ["media", "calendar", "timer"])
    #expect(layout.tabs.flatMap(\.widgets) == ["media", "calendar", "timer"])
    #expect(Set(layout.seenKinds) == Set(kinds.map(\.0)))
  }

  @Test func laterWidgetsWaitInTheGallery() {
    var layout = WidgetLayout(
      tabs: [Tab(id: "home", title: "Home", symbol: "house", widgets: ["media"])],
      seenKinds: ["media"])
    layout.adoptNewKinds([("media", 2), ("notes", 2)], defaults: ["media"])
    #expect(layout.tabs[0].widgets == ["media"])
    #expect(layout.seenKinds.contains("notes"))
  }

  @Test func placeUsesTheFirstTabWithRoomOrANewOne() {
    var layout = WidgetLayout(
      tabs: [Tab(id: "home", title: "Home", symbol: "house", widgets: ["a", "b", "c"])])
    let widths = ["a": 2, "b": 2, "c": 2, "d": 1]
    layout.place("d", units: 1, widths: widths)
    #expect(layout.tabs.count == 2)
    #expect(layout.tabs[1].widgets == ["d"])
    layout.place("d", units: 1, widths: widths)
    #expect(layout.tabs.flatMap(\.widgets).filter { $0 == "d" }.count == 1)
  }

  @Test func newKindsAreAddedOnceToATabWithRoom() {
    var layout = WidgetLayout(tabs: [Tab(id: "a", title: "A", symbol: "star", widgets: ["timer"])])
    layout.adoptNewKinds([("calendar", 2), ("timer", 2), ("battery", 1)])
    #expect(layout.tabs[0].widgets == ["timer", "calendar", "battery"])

    // The user removes calendar; it must not come back on the next launch.
    layout.tabs[0].widgets.removeAll { $0 == "calendar" }
    layout.adoptNewKinds([("calendar", 2), ("timer", 2), ("battery", 1)])
    #expect(layout.tabs[0].widgets == ["timer", "battery"])
  }

  @Test func fullTabsOverflowIntoMoreTabs() {
    var layout = WidgetLayout(tabs: [])
    layout.adoptNewKinds([("a", 2), ("b", 2), ("c", 2), ("d", 2), ("e", 1)])
    #expect(layout.tabs.map(\.widgets) == [["a", "b", "c"], ["d", "e"]])
    #expect(layout.tabs[1].id == "more-1")
  }

  @Test func emptyLayoutGetsAHomeTab() {
    var layout = WidgetLayout(tabs: [])
    layout.adoptNewKinds([("calendar", 2)])
    #expect(layout.tabs.map(\.id) == ["home"])
    #expect(layout.tabs[0].widgets == ["calendar"])
  }

  @Test func unknownAndDuplicateKindsAreRemoved() {
    var layout = WidgetLayout(tabs: [
      Tab(id: "a", title: "A", symbol: "star", widgets: ["timer", "warp-drive"]),
      Tab(id: "b", title: "B", symbol: "star", widgets: ["timer", "battery"]),
    ])
    layout.removeUnknown(knownKinds: ["timer", "battery"])
    #expect(layout.tabs[0].widgets == ["timer"])
    #expect(layout.tabs[1].widgets == ["battery"])
  }
}

@MainActor
struct LayoutStoreTests {
  private let fileURL = FileManager.default.temporaryDirectory
    .appending(path: "LayoutStoreTests-\(UUID().uuidString)/layout.json")

  private func cleanUp() {
    try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
  }

  private func makeStore() async -> LayoutStore {
    let store = LayoutStore(
      fileURL: fileURL, knownKinds: [("calendar", 2), ("timer", 2), ("battery", 1)])
    await store.load()
    return store
  }

  @Test func firstLaunchCreatesTheDefaultLayout() async {
    defer { cleanUp() }
    let store = await makeStore()
    #expect(store.layout.tabs.count == 1)
    #expect(store.layout.tabs[0].widgets == ["calendar", "timer", "battery"])
  }

  @Test func editsAreSavedAndReloaded() async throws {
    defer { cleanUp() }
    let store = await makeStore()
    let tabID = store.addTab(title: "Work")
    store.add("calendar", to: tabID)  // already placed in home; ignored
    store.remove("battery")
    store.add("battery", to: tabID)
    store.moveWidgets(in: "home", from: IndexSet(integer: 1), to: 0)

    for _ in 0..<50 where !FileManager.default.fileExists(atPath: fileURL.path()) {
      try await Task.sleep(for: .milliseconds(20))
    }
    try await Task.sleep(for: .milliseconds(400))
    let reloaded = await makeStore()
    #expect(reloaded.layout.tabs.map(\.title) == [store.layout.tabs[0].title, "Work"])
    #expect(reloaded.layout.tabs[0].widgets == ["timer", "calendar"])
    #expect(reloaded.layout.tabs[1].widgets == ["battery"])
  }

  @Test func removingATabMovesItsWidgetsToTheFirstTab() async {
    defer { cleanUp() }
    let store = await makeStore()
    let tabID = store.addTab(title: "Extra")
    store.remove("timer")
    store.add("timer", to: tabID)
    store.removeTab(tabID)
    #expect(store.layout.tabs.count == 1)
    #expect(store.layout.tabs[0].widgets.contains("timer"))
    store.removeTab(store.layout.tabs[0].id)
    #expect(store.layout.tabs.count == 1)
  }
}
