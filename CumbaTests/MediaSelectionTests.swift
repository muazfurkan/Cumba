import Foundation
import Testing

@testable import Cumba

struct MediaSelectionTests {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  private func track(
    _ source: NowPlaying.Source, _ title: String, playing: Bool, at date: Date? = nil
  ) -> NowPlaying {
    NowPlaying(
      source: source, title: title, duration: 200, position: 10,
      positionTimestamp: date ?? start, isPlaying: playing)
  }

  @Test func playingSourceWins() {
    var selection = MediaSelection()
    selection.update(track(.spotify, "A", playing: false), for: .spotify, at: start)
    selection.update(track(.appleMusic, "B", playing: true), for: .appleMusic, at: start)
    #expect(selection.current(at: start)?.source == .appleMusic)
  }

  @Test func latestStartedWinsWhenSeveralPlay() {
    var selection = MediaSelection()
    selection.update(track(.spotify, "A", playing: true), for: .spotify, at: start)
    selection.update(
      track(.appleMusic, "B", playing: true), for: .appleMusic, at: start.addingTimeInterval(5))
    #expect(selection.current(at: start.addingTimeInterval(6))?.source == .appleMusic)
    // A new track on Spotify while it keeps playing doesn't count as starting again.
    selection.update(
      track(.spotify, "C", playing: true), for: .spotify, at: start.addingTimeInterval(7))
    #expect(selection.current(at: start.addingTimeInterval(8))?.source == .appleMusic)
  }

  @Test func pausedSourceStaysForTenMinutes() {
    var selection = MediaSelection()
    selection.update(track(.spotify, "A", playing: true), for: .spotify, at: start)
    selection.update(track(.spotify, "A", playing: false), for: .spotify, at: start)
    #expect(selection.current(at: start.addingTimeInterval(9 * 60))?.title == "A")
    #expect(selection.current(at: start.addingTimeInterval(10 * 60 + 1)) == nil)
    #expect(selection.nextExpiry(after: start) == start.addingTimeInterval(10 * 60))
  }

  @Test func repeatedPauseUpdatesKeepTheFirstPauseTime() {
    var selection = MediaSelection()
    selection.update(track(.appleMusic, "A", playing: false), for: .appleMusic, at: start)
    selection.update(
      track(.appleMusic, "A", playing: false), for: .appleMusic, at: start.addingTimeInterval(500))
    #expect(selection.current(at: start.addingTimeInterval(601)) == nil)
  }

  @Test func pinnedSourceWinsWhileVisible() {
    var selection = MediaSelection()
    selection.update(track(.spotify, "A", playing: true), for: .spotify, at: start)
    selection.update(track(.appleMusic, "B", playing: false), for: .appleMusic, at: start)
    selection.pinnedSource = .appleMusic
    #expect(selection.current(at: start)?.source == .appleMusic)
    #expect(selection.availableSources(at: start) == [.spotify, .appleMusic])
    #expect(selection.current(at: start.addingTimeInterval(700))?.source == .spotify)
  }

  @Test func quittingRemovesTheSource() {
    var selection = MediaSelection()
    selection.update(track(.spotify, "A", playing: true), for: .spotify, at: start)
    selection.update(nil, for: .spotify, at: start)
    #expect(selection.current(at: start) == nil)
  }

  @Test func positionAdvancesOnlyWhilePlaying() {
    let playing = track(.spotify, "A", playing: true)
    #expect(playing.currentPosition(at: start.addingTimeInterval(5)) == 15)
    #expect(playing.currentPosition(at: start.addingTimeInterval(500)) == 200)
    let paused = track(.spotify, "A", playing: false)
    #expect(paused.currentPosition(at: start.addingTimeInterval(5)) == 10)
  }
}
