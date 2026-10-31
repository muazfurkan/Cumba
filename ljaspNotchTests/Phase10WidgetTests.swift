import Foundation
import Testing

@testable import ljaspNotch

@MainActor
struct PomodoroTests {
  private func makeWidget() throws -> (PomodoroWidget, UserDefaults, String) {
    let suite = "PomodoroTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (
      PomodoroWidget(defaults: defaults, liveActivities: LiveActivityCenter()), defaults, suite
    )
  }

  @Test func roundsFollowFocusBreakAndALongBreakAfterFour() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    var rounds: [PomodoroWidget.Round] = []
    for _ in 0..<8 {
      rounds.append(widget.round)
      widget.advance(countingFocus: true)
    }
    #expect(
      rounds == [
        .focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak,
      ])
    #expect(widget.round == .focus)
    #expect(widget.finishedInSet == 0)
    #expect(widget.finishedToday == 4)
  }

  @Test func skippedFocusDoesNotCount() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    widget.skip()
    #expect(widget.round == .shortBreak)
    #expect(widget.finishedToday == 0)
  }

  @Test func lengthsPersist() throws {
    let (widget, defaults, suite) = try makeWidget()
    defer { defaults.removePersistentDomain(forName: suite) }
    widget.focusMinutes = 50
    #expect(
      PomodoroWidget(defaults: defaults, liveActivities: LiveActivityCenter()).focusMinutes == 50)
  }
}

@MainActor
struct KeepAwakeTests {
  @Test func turnsOnAndOff() {
    let center = LiveActivityCenter()
    let widget = KeepAwakeWidget(
      context: WidgetContext(
        liveActivities: center, media: MediaCoordinator(providers: []),
        claude: ClaudeCodeService(liveActivities: center), openSettings: { _ in }))
    widget.turnOn(minutes: 30)
    #expect(widget.isOn)
    #expect(widget.endsAt != nil)
    #expect(center.contains("keepAwake"))
    widget.turnOff()
    #expect(!widget.isOn)
    #expect(!center.contains("keepAwake"))
  }
}
