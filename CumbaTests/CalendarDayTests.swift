import Foundation
import Testing

@testable import Cumba

@MainActor
struct CalendarDayTests {
  private func makeWidget() -> CalendarWidget {
    let center = LiveActivityCenter()
    return CalendarWidget(
      context: WidgetContext(
        liveActivities: center, media: MediaCoordinator(providers: []),
        claude: ClaudeCodeService(liveActivities: center), panel: PanelControl(),
        openSettings: { _ in }))
  }

  @Test func picksADayAndForgetsItOffScreen() throws {
    let widget = makeWidget()
    #expect(widget.pickedDay == nil)
    let later = try #require(Calendar.current.date(byAdding: .day, value: 3, to: .now))
    widget.select(later)
    #expect(widget.pickedDay == Calendar.current.startOfDay(for: later))
    widget.select(.now)
    #expect(widget.pickedDay == nil)
    widget.select(later)
    widget.deactivate()
    #expect(widget.pickedDay == nil)
    #expect(widget.pickedDayEvents.isEmpty)
  }
}
