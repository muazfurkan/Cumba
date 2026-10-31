import Foundation
import Testing

@testable import ljaspNotch

/// Notification payloads in the shape Spotify and Music post them. Re-check the fields
/// against real players when macOS or the players change.
struct PlayerAdapterTests {
  private let date = Date(timeIntervalSince1970: 1_800_000_000)

  @Test func parsesSpotifyNotification() throws {
    let info: [AnyHashable: Any] = [
      "Player State": "Playing",
      "Name": "Song Title",
      "Artist": "Artist",
      "Album": "Album",
      "Duration": NSNumber(value: 215_300),
      "Playback Position": NSNumber(value: 42.5),
      "Track ID": "spotify:track:abc",
    ]
    let track = try #require(SpotifyAdapter().parse(notification: info, at: date))
    #expect(track.source == .spotify)
    #expect(track.title == "Song Title")
    #expect(track.duration == 215.3)
    #expect(track.position == 42.5)
    #expect(track.isPlaying)
  }

  @Test func spotifyStoppedMeansNothing() {
    let info: [AnyHashable: Any] = ["Player State": "Stopped", "Name": "Song"]
    #expect(SpotifyAdapter().parse(notification: info, at: date) == nil)
  }

  @Test func parsesMusicNotification() throws {
    let info: [AnyHashable: Any] = [
      "Player State": "Paused",
      "Name": "Track",
      "Artist": "",
      "Album": "Album",
      "Total Time": NSNumber(value: 180_000),
    ]
    let track = try #require(MusicAdapter().parse(notification: info, at: date))
    #expect(track.source == .appleMusic)
    #expect(track.artist == nil)
    #expect(track.duration == 180)
    #expect(track.position == nil)
    #expect(!track.isPlaying)
  }

  @Test func missingTitleIsIgnored() {
    #expect(MusicAdapter().parse(notification: ["Player State": "Playing"], at: date) == nil)
  }

  @Test func parsesStateScriptResults() throws {
    let list = NSAppleEventDescriptor.list()
    for (index, value) in [
      NSAppleEventDescriptor(string: "playing"), NSAppleEventDescriptor(string: "Song"),
      NSAppleEventDescriptor(string: "Artist"), NSAppleEventDescriptor(string: "Album"),
      NSAppleEventDescriptor(double: 215_300), NSAppleEventDescriptor(double: 12),
    ].enumerated() {
      list.insert(value, at: index + 1)
    }
    let spotify = try #require(SpotifyAdapter().parse(state: list, at: date))
    #expect(spotify.duration == 215.3)
    #expect(spotify.position == 12)
    #expect(spotify.isPlaying)

    let stopped = NSAppleEventDescriptor.list()
    stopped.insert(NSAppleEventDescriptor(string: "stopped"), at: 1)
    #expect(MusicAdapter().parse(state: stopped, at: date) == nil)
  }

  @Test func commandsTargetTheBundleAndNeverUseTheAppName() {
    let script = MusicAdapter().commandScript(.seek(-5))
    #expect(script == "tell application id \"com.apple.Music\" to set player position to 0.0")
    #expect(SpotifyAdapter().commandScript(.next).contains("com.spotify.client"))
  }

  @Test func spotifyArtworkMustBeHTTPS() {
    var track = NowPlaying(
      source: .spotify, title: "A", positionTimestamp: date, isPlaying: true)
    SpotifyAdapter().applyArtwork(
      NSAppleEventDescriptor(string: "http://example.com/a.jpg"), to: &track)
    #expect(track.artworkURL == nil)
    SpotifyAdapter().applyArtwork(
      NSAppleEventDescriptor(string: "https://i.scdn.co/image/abc"), to: &track)
    #expect(track.artworkURL?.host() == "i.scdn.co")
  }
}
