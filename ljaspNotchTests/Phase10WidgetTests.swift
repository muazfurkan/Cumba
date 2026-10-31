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

@MainActor
private func makeContext(panel: PanelControl = PanelControl()) -> WidgetContext {
  let center = LiveActivityCenter()
  return WidgetContext(
    liveActivities: center, media: MediaCoordinator(providers: []),
    claude: ClaudeCodeService(liveActivities: center), panel: panel, openSettings: { _ in })
}

@MainActor
struct ClipboardHistoryTests {
  @Test func keepsNewestFirstWithoutDuplicates() {
    let widget = ClipboardHistoryWidget(context: makeContext())
    defer { widget.shutdown() }
    widget.record("one")
    widget.record("  two \n")
    widget.record("one")
    widget.record("   ")
    #expect(widget.entries.map(\.text) == ["one", "two"])
  }

  @Test func staysWithinTheLimits() {
    let widget = ClipboardHistoryWidget(context: makeContext())
    defer { widget.shutdown() }
    for index in 0..<(ClipboardHistoryWidget.maxEntries + 5) {
      widget.record("item \(index)")
    }
    widget.record(String(repeating: "x", count: ClipboardHistoryWidget.maxLength + 10))
    #expect(widget.entries.count == ClipboardHistoryWidget.maxEntries)
    #expect(widget.entries[0].text.count == ClipboardHistoryWidget.maxLength)
  }
}

@MainActor
struct TeleprompterTests {
  @Test func runningKeepsThePanelOpenAndHidden() throws {
    let suite = "TeleprompterTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let panel = PanelControl()
    var keptOpen = false
    var hidden = false
    panel.keepOpen = { keptOpen = $0 }
    panel.hideFromCapture = { hidden = $0 }
    let widget = TeleprompterWidget(defaults: defaults, panel: panel)
    widget.start()
    #expect(!widget.isRunning)  // No script yet.
    widget.text = "Hello"
    widget.start()
    #expect(widget.isRunning && keptOpen && hidden)
    widget.pause()
    #expect(!widget.isRunning && !keptOpen && !hidden)
    #expect(widget.offset(at: .now) >= 0)
    widget.restart()
    #expect(widget.offset(at: .now) == 0)
  }
}

@MainActor
struct NotesTests {
  @Test func savesAndLoads() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "notes-\(UUID()).txt")
    defer { try? FileManager.default.removeItem(at: url) }
    let widget = NotesWidget(fileURL: url, panel: PanelControl())
    await widget.load()
    widget.text = "Buy milk"
    widget.shutdown()
    try await Task.sleep(for: .milliseconds(300))
    let again = NotesWidget(fileURL: url, panel: PanelControl())
    await again.load()
    #expect(again.text == "Buy milk")
  }
}

struct MeetingLinkTests {
  @Test func findsKnownMeetingServices() throws {
    let zoom = try #require(URL(string: "https://us02web.zoom.us/j/123?pwd=x"))
    #expect(MeetingLink.find(url: zoom, texts: []) == zoom)
    let found = MeetingLink.find(
      url: nil, texts: [nil, "Room 4", "Join: https://meet.google.com/abc-defg-hij thanks"])
    #expect(found?.host() == "meet.google.com")
  }

  @Test func ignoresOtherOrInsecureLinks() throws {
    #expect(MeetingLink.find(url: nil, texts: ["See https://example.com/zoom.us"]) == nil)
    let insecure = try #require(URL(string: "http://zoom.us/j/1"))
    #expect(MeetingLink.find(url: insecure, texts: []) == nil)
    #expect(MeetingLink.find(url: nil, texts: ["https://evilzoom.us/j/1"]) == nil)
  }
}

@MainActor
struct MediaSourceTests {
  @Test func disabledSourcesArePersistedAndIgnored() throws {
    let suite = "MediaSourceTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let media = MediaCoordinator(providers: [], defaults: defaults)
    media.disabledSources = [.spotify]
    media.receive(
      NowPlaying(
        source: .spotify, title: "Song", duration: 200, position: 10, positionTimestamp: .now,
        isPlaying: true), from: .spotify)
    #expect(media.current == nil)
    #expect(MediaCoordinator(providers: [], defaults: defaults).disabledSources == [.spotify])
  }
}
