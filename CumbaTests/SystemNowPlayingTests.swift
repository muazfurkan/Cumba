import Foundation
import Testing

@testable import Cumba

struct SystemNowPlayingMessageTests {
  @Test func decodesALineFromTheHelper() throws {
    let line =
      #"{"album":"","appName":"YouTube","artist":"HTalks","artwork":"AAEC","artworkID":"00000000000000ab","bundleID":"com.google.Chrome.app.agimnkijcaahngcdmfeangaknmldooml","duration":7529.08,"elapsed":4745.8,"playing":true,"timestamp":1793487781.99,"title":"Match review"}"#
    let message = try #require(SystemNowPlayingMessage.decode(line))
    #expect(message.artwork == Data([0, 1, 2]))
    let now = Date(timeIntervalSince1970: 1_793_487_791.99)
    let nowPlaying = try #require(message.nowPlaying(artwork: message.artwork, receivedAt: now))
    #expect(nowPlaying.source == .youtube)
    #expect(nowPlaying.title == "Match review")
    #expect(nowPlaying.album == nil)
    #expect(nowPlaying.sourceName == "YouTube")
    #expect(nowPlaying.isPlaying)
    let position = try #require(nowPlaying.currentPosition(at: now))
    #expect(abs(position - 4755.8) < 0.01)
  }

  @Test func nothingPlayingAndErrorsAreRecognized() throws {
    let empty = try #require(SystemNowPlayingMessage.decode(#"{"artworkID":"0000000000000000"}"#))
    #expect(empty.nowPlaying(artwork: nil, receivedAt: .now) == nil)
    #expect(SystemNowPlayingMessage.decode(#"{"error":"unavailable"}"#)?.error == "unavailable")
    #expect(SystemNowPlayingMessage.decode("not json") == nil)
  }

  @Test func mapsAppsToSources() {
    let cases: [(String?, NowPlaying.Source)] = [
      ("com.spotify.client", .spotify),
      ("com.apple.Music", .appleMusic),
      ("com.google.Chrome.app.agimnkijcaahngcdmfeangaknmldooml", .youtube),
      ("com.google.Chrome.app.cinhimbnkkaeohfgghhklpknlkffjgod", .youtubeMusic),
      ("com.google.Chrome", .browser),
      ("com.apple.Safari", .browser),
      ("company.thebrowser.Browser", .browser),
      ("com.apple.podcasts", .otherApp),
      (nil, .otherApp),
    ]
    for (bundleID, source) in cases {
      #expect(SystemNowPlayingMessage.source(forBundleID: bundleID) == source)
    }
  }

  @Test func commandsAreSingleWords() {
    #expect(SystemNowPlayingMessage.commandLine(for: .togglePlayPause) == "toggle")
    #expect(SystemNowPlayingMessage.commandLine(for: .next) == "next")
    #expect(SystemNowPlayingMessage.commandLine(for: .previous) == "previous")
    #expect(SystemNowPlayingMessage.commandLine(for: .seek(-3)) == "seek 0.0")
    #expect(SystemNowPlayingMessage.commandLine(for: .seek(12.5)) == "seek 12.5")
  }
}

@MainActor
struct SystemNowPlayingCoordinatorTests {
  private func track(_ source: NowPlaying.Source, _ title: String) -> NowPlaying {
    NowPlaying(
      source: source, title: title, positionTimestamp: .now, isPlaying: true)
  }

  @Test func theSystemsAppReplacesTheLastOne() {
    // Never started, so no helper process runs.
    let media = MediaCoordinator(providers: [], system: SystemNowPlayingProvider())
    #expect(media.isUsingSystemNowPlaying)
    media.receiveSystem(track(.spotify, "Song"))
    #expect(media.current?.title == "Song")
    media.receiveSystem(track(.browser, "Video"))
    #expect(media.current?.title == "Video")
    #expect(media.availableSources == [.browser])
    media.receiveSystem(nil)
    #expect(media.current == nil)
  }

  @Test func otherProvidersAreIgnoredWhileTheSystemIsUsed() {
    let media = MediaCoordinator(providers: [], system: SystemNowPlayingProvider())
    media.receive(track(.youtube, "From the extension"), from: .youtube)
    #expect(media.current == nil)
    media.disabledSources = [.otherApp]
    media.receiveSystem(track(.otherApp, "Podcast"))
    #expect(media.current == nil)
  }
}
