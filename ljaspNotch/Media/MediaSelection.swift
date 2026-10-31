import Foundation

/// Decides which player the media widget shows:
/// - A playing source wins; with several, the one that started playing last.
/// - With nothing playing, the last paused source stays for 10 minutes, then disappears.
/// - A source the user picked by hand wins while it has something to show.
struct MediaSelection: Equatable, Sendable {
  struct Entry: Equatable, Sendable {
    var nowPlaying: NowPlaying
    var startedPlayingAt: Date?
    var pausedAt: Date?
  }

  static let pausedTimeout: TimeInterval = 10 * 60

  private(set) var entries: [NowPlaying.Source: Entry] = [:]
  var pinnedSource: NowPlaying.Source?

  mutating func update(_ nowPlaying: NowPlaying?, for source: NowPlaying.Source, at date: Date) {
    guard let nowPlaying else {
      entries[source] = nil
      return
    }
    let old = entries[source]
    var entry = Entry(nowPlaying: nowPlaying)
    if nowPlaying.isPlaying {
      let wasPlaying = old?.nowPlaying.isPlaying ?? false
      entry.startedPlayingAt = wasPlaying ? old?.startedPlayingAt : date
    } else {
      let wasPaused = old.map { !$0.nowPlaying.isPlaying } ?? false
      entry.pausedAt = wasPaused ? (old?.pausedAt ?? date) : date
      entry.startedPlayingAt = old?.startedPlayingAt
    }
    entries[source] = entry
  }

  func current(at date: Date) -> NowPlaying? {
    if let pinnedSource, let entry = entries[pinnedSource], isVisible(entry, at: date) {
      return entry.nowPlaying
    }
    let playing = entries.values.filter(\.nowPlaying.isPlaying)
    if let latest = playing.max(by: { started($0) < started($1) }) {
      return latest.nowPlaying
    }
    return entries.values
      .filter { isVisible($0, at: date) }
      .max { ($0.pausedAt ?? .distantPast) < ($1.pausedAt ?? .distantPast) }?
      .nowPlaying
  }

  /// Sources with something to show, for switching by hand.
  func availableSources(at date: Date) -> [NowPlaying.Source] {
    NowPlaying.Source.allCases.filter { source in
      entries[source].map { isVisible($0, at: date) } ?? false
    }
  }

  /// When the next paused source times out, so the caller can refresh once then.
  func nextExpiry(after date: Date) -> Date? {
    entries.values
      .compactMap {
        $0.nowPlaying.isPlaying ? nil : $0.pausedAt?.addingTimeInterval(Self.pausedTimeout)
      }
      .filter { $0 > date }
      .min()
  }

  private func isVisible(_ entry: Entry, at date: Date) -> Bool {
    if entry.nowPlaying.isPlaying {
      return true
    }
    guard let pausedAt = entry.pausedAt else { return false }
    return date.timeIntervalSince(pausedAt) < Self.pausedTimeout
  }

  private func started(_ entry: Entry) -> Date {
    entry.startedPlayingAt ?? .distantPast
  }
}
