import Foundation

/// Messages between the Chrome extension and the app over `ws://127.0.0.1:<port>/media`
/// (SPEC § 8).
enum BrowserMessage: Equatable, Sendable {
  struct TabState: Codable, Equatable, Sendable {
    var tabId: Int
    var site: String
    var title: String
    var artist: String?
    var album: String?
    var artworkUrl: String?
    var videoId: String?
    var duration: Double?
    var position: Double?
    var isPlaying: Bool
    /// Milliseconds since 1970 when the extension read the state.
    var sentAt: Double?
  }

  case hello(version: Int, token: String)
  case state(TabState)
  case closed(tabId: Int)
  case ping

  /// Longest text field accepted; longer values are cut so a broken page can't flood us.
  static let maxTextLength = 300

  static func decode(_ text: String) -> BrowserMessage? {
    let data = Data(text.utf8)
    let decoder = JSONDecoder()
    guard data.count <= 16_384,
      let envelope = try? decoder.decode(Envelope.self, from: data)
    else { return nil }
    switch envelope.type {
    case "hello":
      guard let hello = try? decoder.decode(Hello.self, from: data) else { return nil }
      return .hello(version: hello.version, token: hello.token)
    case "state":
      guard var state = try? decoder.decode(TabState.self, from: data),
        NowPlaying.Source(site: state.site) != nil
      else { return nil }
      state.title = String(state.title.prefix(maxTextLength))
      state.artist = state.artist.map { String($0.prefix(maxTextLength)) }
      state.album = state.album.map { String($0.prefix(maxTextLength)) }
      return .state(state)
    case "closed":
      guard let closed = try? decoder.decode(Closed.self, from: data) else { return nil }
      return .closed(tabId: closed.tabId)
    case "ping":
      return .ping
    default:
      return nil
    }
  }

  /// `{"type":"command","tabId":812,"action":"seek","position":90}`
  static func encode(_ command: MediaCommand, tabId: Int) -> String {
    var object: [String: Any] = ["type": "command", "tabId": tabId]
    switch command {
    case .togglePlayPause: object["action"] = "toggle"
    case .next: object["action"] = "next"
    case .previous: object["action"] = "previous"
    case .seek(let position):
      object["action"] = "seek"
      object["position"] = max(0, position)
    }
    let data =
      (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    return String(decoding: data, as: UTF8.self)
  }

  private struct Envelope: Decodable { let type: String }
  private struct Hello: Decodable {
    let version: Int
    let token: String
  }
  private struct Closed: Decodable { let tabId: Int }
}

extension NowPlaying.Source {
  init?(site: String) {
    switch site {
    case "youtube": self = .youtube
    case "youtubeMusic": self = .youtubeMusic
    default: return nil
    }
  }
}

extension BrowserMessage.TabState {
  func nowPlaying(receivedAt: Date) -> NowPlaying? {
    guard let source = NowPlaying.Source(site: site), !title.isEmpty else { return nil }
    // Trust the extension's clock only when it is close to ours.
    let sent = sentAt.map { Date(timeIntervalSince1970: $0 / 1000) }
    let timestamp = sent.flatMap { abs($0.timeIntervalSince(receivedAt)) < 10 ? $0 : nil }
    let artwork = artworkUrl.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
    return NowPlaying(
      source: source,
      title: title,
      artist: artist?.isEmpty == false ? artist : nil,
      album: album?.isEmpty == false ? album : nil,
      artworkURL: artwork,
      duration: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
      position: position.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil },
      positionTimestamp: timestamp ?? receivedAt,
      isPlaying: isPlaying)
  }
}
