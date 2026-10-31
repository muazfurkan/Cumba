import Foundation

/// What differs between scriptable players: notification format, state script and artwork.
/// Everything here is pure parsing, so it is unit tested with recorded payloads.
protocol PlayerAdapter: Sendable {
  var source: NowPlaying.Source { get }
  var bundleID: String { get }
  /// Distributed notification the player posts on every change.
  var notificationName: String { get }
  /// Returns `{state, name, artist, album, duration, position[, artwork url]}` or `{"stopped"}`.
  var stateScript: String { get }
  var artworkScript: String { get }

  func parse(notification info: [AnyHashable: Any], at date: Date) -> NowPlaying?
  func parse(state: NSAppleEventDescriptor, at date: Date) -> NowPlaying?
  func applyArtwork(_ descriptor: NSAppleEventDescriptor, to nowPlaying: inout NowPlaying)
}

extension PlayerAdapter {
  func commandScript(_ command: MediaCommand) -> String {
    let verb =
      switch command {
      case .togglePlayPause: "playpause"
      case .next: "next track"
      case .previous: "previous track"
      case .seek(let position): "set player position to \(max(0, position))"
      }
    return "tell application id \"\(bundleID)\" to \(verb)"
  }

  /// Shared shape of both state scripts: a list whose first item is the player state.
  fileprivate func parseStateList(
    _ state: NSAppleEventDescriptor, at date: Date, durationScale: Double
  ) -> NowPlaying? {
    let items = state.listItems
    guard items.count >= 6, let playerState = items[0].stringValue?.lowercased(),
      playerState != "stopped", let title = items[1].stringValue, !title.isEmpty
    else { return nil }
    let duration = items[4].doubleValue * durationScale
    return NowPlaying(
      source: source,
      title: title,
      artist: items[2].stringValue.nonEmpty,
      album: items[3].stringValue.nonEmpty,
      duration: duration > 0 ? duration : nil,
      position: items[5].doubleValue,
      positionTimestamp: date,
      isPlaying: playerState == "playing")
  }
}

struct SpotifyAdapter: PlayerAdapter {
  let source = NowPlaying.Source.spotify
  let bundleID = "com.spotify.client"
  let notificationName = "com.spotify.client.PlaybackStateChanged"
  let stateScript = """
    tell application id "com.spotify.client"
      if player state is stopped then return {"stopped"}
      set t to current track
      return {player state as string, name of t, artist of t, album of t, duration of t, player position}
    end tell
    """
  let artworkScript = "tell application id \"com.spotify.client\" to artwork url of current track"

  func parse(notification info: [AnyHashable: Any], at date: Date) -> NowPlaying? {
    guard let state = info["Player State"] as? String, state != "Stopped",
      let title = info["Name"] as? String, !title.isEmpty
    else { return nil }
    // Duration is in milliseconds, position in seconds.
    let durationMS = (info["Duration"] as? NSNumber)?.doubleValue ?? 0
    return NowPlaying(
      source: source,
      title: title,
      artist: (info["Artist"] as? String).nonEmpty,
      album: (info["Album"] as? String).nonEmpty,
      duration: durationMS > 0 ? durationMS / 1000 : nil,
      position: (info["Playback Position"] as? NSNumber)?.doubleValue,
      positionTimestamp: date,
      isPlaying: state == "Playing")
  }

  func parse(state: NSAppleEventDescriptor, at date: Date) -> NowPlaying? {
    parseStateList(state, at: date, durationScale: 1.0 / 1000)
  }

  func applyArtwork(_ descriptor: NSAppleEventDescriptor, to nowPlaying: inout NowPlaying) {
    if let string = descriptor.stringValue, let url = URL(string: string), url.scheme == "https" {
      nowPlaying.artworkURL = url
    }
  }
}

struct MusicAdapter: PlayerAdapter {
  let source = NowPlaying.Source.appleMusic
  let bundleID = "com.apple.Music"
  let notificationName = "com.apple.Music.playerInfo"
  let stateScript = """
    tell application id "com.apple.Music"
      if player state is stopped then return {"stopped"}
      set t to current track
      return {player state as string, name of t, artist of t, album of t, duration of t, player position}
    end tell
    """
  let artworkScript = """
    tell application id "com.apple.Music" to get raw data of artwork 1 of current track
    """

  func parse(notification info: [AnyHashable: Any], at date: Date) -> NowPlaying? {
    guard let state = info["Player State"] as? String, state != "Stopped",
      let title = info["Name"] as? String, !title.isEmpty
    else { return nil }
    // Music sends "Total Time" in milliseconds and no position; the provider asks for the
    // position with AppleScript when it may.
    let durationMS = (info["Total Time"] as? NSNumber)?.doubleValue ?? 0
    return NowPlaying(
      source: source,
      title: title,
      artist: (info["Artist"] as? String).nonEmpty,
      album: (info["Album"] as? String).nonEmpty,
      duration: durationMS > 0 ? durationMS / 1000 : nil,
      position: nil,
      positionTimestamp: date,
      isPlaying: state == "Playing")
  }

  func parse(state: NSAppleEventDescriptor, at date: Date) -> NowPlaying? {
    parseStateList(state, at: date, durationScale: 1)
  }

  func applyArtwork(_ descriptor: NSAppleEventDescriptor, to nowPlaying: inout NowPlaying) {
    let data = descriptor.data
    if !data.isEmpty {
      nowPlaying.artworkData = data
    }
  }
}

extension Optional where Wrapped == String {
  /// Nil for nil and for empty strings.
  fileprivate var nonEmpty: String? {
    guard let self, !self.isEmpty else { return nil }
    return self
  }
}
