import Foundation

/// What a player is playing.
struct NowPlaying: Equatable, Sendable {
  enum Source: String, CaseIterable, Sendable {
    case spotify
    case appleMusic
    case youtube
    case youtubeMusic
  }

  var source: Source
  var title: String
  var artist: String?
  var album: String?
  var artworkURL: URL?
  var artworkData: Data?
  var duration: TimeInterval?
  var position: TimeInterval?
  /// The progress bar advances locally from this moment instead of asking the player.
  var positionTimestamp: Date
  var isPlaying: Bool

  /// Position now, estimated from the last known position while playing.
  func currentPosition(at date: Date = .now) -> TimeInterval? {
    guard let position else { return nil }
    let elapsed = isPlaying ? date.timeIntervalSince(positionTimestamp) : 0
    let estimate = position + max(0, elapsed)
    if let duration {
      return min(estimate, duration)
    }
    return estimate
  }

  /// Same track, ignoring playback state and position.
  func isSameTrack(as other: NowPlaying?) -> Bool {
    guard let other else { return false }
    return source == other.source && title == other.title && artist == other.artist
      && album == other.album
  }
}

enum MediaCommand: Equatable, Sendable {
  case togglePlayPause
  case next
  case previous
  case seek(TimeInterval)
}

/// A source of `NowPlaying` updates that can be controlled. Adding a source means
/// implementing this protocol and registering it with the `MediaCoordinator`.
@MainActor
protocol MediaProvider: AnyObject {
  var source: NowPlaying.Source { get }
  /// Called with every change; nil when the player stopped or quit.
  var onUpdate: ((NowPlaying?) -> Void)? { get set }
  func start()
  func send(_ command: MediaCommand) async
}

extension NowPlaying.Source {
  var displayName: String {
    switch self {
    case .spotify: "Spotify"
    case .appleMusic: String(localized: "Music", comment: "Apple Music app name")
    case .youtube: "YouTube"
    case .youtubeMusic: "YouTube Music"
    }
  }

  var symbol: String {
    switch self {
    case .spotify: "dot.radiowaves.left.and.right"
    case .appleMusic: "music.note"
    case .youtube: "play.rectangle"
    case .youtubeMusic: "music.note.tv"
    }
  }
}
