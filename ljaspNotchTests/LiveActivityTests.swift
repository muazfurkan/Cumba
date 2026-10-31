import SwiftUI
import Testing

@testable import ljaspNotch

@MainActor
struct LiveActivityCenterTests {
  private func activity(_ id: String, _ priority: LiveActivity.Priority) -> LiveActivity {
    LiveActivity(
      id: id, priority: priority, leading: AnyView(EmptyView()), trailing: AnyView(EmptyView()))
  }

  @Test func highestPriorityWins() {
    let center = LiveActivityCenter()
    center.show(activity("media", .media))
    center.show(activity("permission", .claudePermission))
    center.show(activity("battery", .battery))
    #expect(center.current?.id == "permission")
    center.dismiss("permission")
    #expect(center.current?.id == "battery")
  }

  @Test func timedActivitiesDisappear() async throws {
    let center = LiveActivityCenter()
    center.show(activity("battery", .battery), for: .milliseconds(20))
    #expect(center.current != nil)
    try await Task.sleep(for: .milliseconds(200))
    #expect(center.current == nil)
  }

  @Test func showingAgainCancelsTheOldExpiry() async throws {
    let center = LiveActivityCenter()
    center.show(activity("battery", .battery), for: .milliseconds(20))
    center.show(activity("battery", .battery))
    try await Task.sleep(for: .milliseconds(200))
    #expect(center.contains("battery"))
  }
}

@MainActor
struct TimerWidgetTests {
  private func makeTimer() -> (TimerWidget, LiveActivityCenter) {
    let center = LiveActivityCenter()
    let timer = TimerWidget(
      context: WidgetContext(
        liveActivities: center, media: MediaCoordinator(providers: []),
        claude: ClaudeCodeService(liveActivities: center), openSettings: { _ in }))
    return (timer, center)
  }

  @Test func startPauseResumeAndReset() throws {
    let (timer, center) = makeTimer()
    timer.select(minutes: 5)
    #expect(timer.length == 300)

    timer.start()
    #expect(timer.isActive)
    #expect(center.current?.priority == .timerRunning)

    timer.pause()
    guard case .paused(let remaining) = timer.phase else {
      Issue.record("Expected paused, got \(timer.phase)")
      return
    }
    #expect(remaining > 290 && remaining <= 300)
    #expect(center.current == nil)

    timer.start()
    #expect(timer.isActive)
    timer.reset()
    #expect(timer.phase == .idle)
    #expect(center.current == nil)
  }

  @Test func lengthCantChangeWhileRunning() {
    let (timer, _) = makeTimer()
    timer.select(minutes: 25)
    timer.start()
    timer.select(minutes: 5)
    #expect(timer.length == 25 * 60)
    timer.shutdown()
  }
}
