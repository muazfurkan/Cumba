import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Cumba

struct TabSwipeTrackerTests {
  private func run(_ moves: [(NSEvent.Phase, CGFloat, CGFloat)]) -> [TabSwipeTracker.Update] {
    var tracker = TabSwipeTracker()
    return moves.compactMap {
      tracker.update(phase: $0.0, fingerDelta: CGSize(width: $0.1, height: $0.2))
    }
  }

  @Test func pagesFollowTheFingersAndLettingGoFarEnoughOpensTheNextTab() {
    let updates = run([
      (.began, 0, 0), (.changed, -25, 2), (.changed, -25, 0), (.changed, -60, 0), (.ended, 0, 0),
    ])
    #expect(updates == [.drag(-25), .drag(-50), .drag(-110), .end(-110)])
    #expect(TabSwipeTracker.step(forTravel: -110) == 1)
  }

  @Test func fingersMovingRightLeadToThePreviousTab() {
    #expect(run([(.began, 0, 0), (.changed, 55, 0), (.ended, 0, 0)]) == [.drag(55), .end(55)])
    #expect(TabSwipeTracker.step(forTravel: 55) == -1)
  }

  @Test func shortMovesSettleBackAndVerticalOnesNeverDrag() {
    #expect(TabSwipeTracker.step(forTravel: -30) == nil)
    #expect(run([(.began, 0, 0), (.changed, -10, 40), (.changed, -80, 0), (.ended, 0, 0)]).isEmpty)
    #expect(run([(.began, 0, 0), (.changed, -3, 0), (.ended, 0, 0)]).isEmpty)
  }

  @Test func eachGestureStartsOver() {
    let gesture: [(NSEvent.Phase, CGFloat, CGFloat)] = [
      (.began, 0, 0), (.changed, -50, 0), (.ended, 0, 0),
    ]
    #expect(run(gesture + gesture) == [.drag(-50), .end(-50), .drag(-50), .end(-50)])
  }
}

@MainActor
struct TabSwipeHostTests {
  @Test func stepsBetweenTabsAndStopsAtTheEnds() async throws {
    let file = FileManager.default.temporaryDirectory
      .appending(path: "TabSwipeTests-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let center = LiveActivityCenter()
    let context = WidgetContext(
      liveActivities: center, media: MediaCoordinator(providers: []),
      claude: ClaudeCodeService(liveActivities: center), panel: PanelControl(),
      openSettings: { _ in })
    let registry = WidgetRegistry(context: context, types: [TimerWidget.self])
    let store = LayoutStore(
      fileURL: file, knownKinds: registry.infos.map { ($0.kind, $0.size.units) },
      defaultKinds: [TimerWidget.kind])
    await store.load()
    let host = WidgetHost(
      layoutStore: store, registry: registry, liveActivities: center,
      claude: ClaudeCodeService(liveActivities: center))
    host.addTab()
    let first = try #require(host.tabs.first?.id)
    let second = try #require(host.tabs.last?.id)
    host.select(first)

    #expect(!host.selectTab(offset: -1))
    #expect(host.selectTab(offset: 1))
    #expect(host.selectedTab?.id == second)
    #expect(host.pageDirection == 1)
    #expect(!host.selectTab(offset: 1))
    #expect(host.selectTab(offset: -1))
    #expect(host.selectedTab?.id == first)
    #expect(host.pageDirection == -1)

    // Dragging left reveals the next tab; letting go early settles back.
    host.dragPages(to: -30)
    #expect(host.swipeNeighbor?.id == second)
    #expect(!host.endPageDrag(travel: -30))
    #expect(host.selectedTab?.id == first)
    #expect(host.pageDrag == 0)
    // Far enough opens it.
    host.dragPages(to: -120)
    #expect(host.endPageDrag(travel: -120))
    #expect(host.selectedTab?.id == second)
    // The panel opens on the chosen tab, or the one it was left on.
    #expect(host.tabToOpen == nil)
    host.openingTab = first
    #expect(host.tabToOpen == first)
    host.openingTab = "deleted"
    #expect(host.tabToOpen == nil)
    // Past the last tab the pages only give a little.
    host.dragPages(to: -80)
    #expect(host.swipeNeighbor == nil)
    #expect(host.pageDrag == -20)
    #expect(!host.endPageDrag(travel: -80))
  }
}

@MainActor
struct SidewaysScrollTests {
  @Test func gesturesOverSidewaysScrollingContentAreLeftToIt() async throws {
    let root = VStack(spacing: 0) {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 0) {
          ForEach(0..<50, id: \.self) { index in
            Text(verbatim: "\(index)").frame(width: 40, height: 30)
          }
        }
      }
      .frame(width: 200, height: 40)
      Text(verbatim: "below").frame(width: 200, height: 40)
    }
    let hosting = NSHostingView(rootView: root)
    let window = NSWindow(
      contentRect: NSRect(x: -5000, y: -5000, width: 200, height: 80), styleMask: .borderless,
      backing: .buffered, defer: false)
    window.contentView = hosting
    window.orderBack(nil)
    defer { window.orderOut(nil) }
    try await Task.sleep(for: .milliseconds(300))
    hosting.layoutSubtreeIfNeeded()

    #expect(TabSwipeMonitor.scrollsSideways(at: NSPoint(x: 100, y: 60), in: window))
    #expect(!TabSwipeMonitor.scrollsSideways(at: NSPoint(x: 100, y: 20), in: window))
  }
}
