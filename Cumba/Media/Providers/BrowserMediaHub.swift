import FlyingFox
import Foundation
import Observation

/// Collects tab states from every connected extension and feeds one provider per site
/// (YouTube, YouTube Music). Picks the right tab when several play.
@MainActor
@Observable
final class BrowserMediaHub {
  struct TabKey: Hashable, Sendable {
    let connection: UUID
    let tabId: Int
  }

  struct Tab: Equatable, Sendable {
    let key: TabKey
    var state: BrowserMessage.TabState
    var receivedAt: Date
    var startedPlayingAt: Date?
  }

  private(set) var connectionCount = 0
  @ObservationIgnored private var tabs: [TabKey: Tab] = [:]
  @ObservationIgnored private var connections: [UUID: AsyncStream<WSMessage>.Continuation] = [:]
  @ObservationIgnored let youtube: BrowserProvider
  @ObservationIgnored let youtubeMusic: BrowserProvider

  init() {
    youtube = BrowserProvider(source: .youtube)
    youtubeMusic = BrowserProvider(source: .youtubeMusic)
    youtube.hub = self
    youtubeMusic.hub = self
  }

  func connected(_ id: UUID, outbound: AsyncStream<WSMessage>.Continuation) {
    connections[id] = outbound
    connectionCount = connections.count
    Log.media.info("Browser extension connected")
  }

  func disconnected(_ id: UUID) {
    connections[id] = nil
    connectionCount = connections.count
    tabs = tabs.filter { $0.key.connection != id }
    publish()
  }

  func isConnected(_ id: UUID) -> Bool {
    connections[id] != nil
  }

  func receive(_ state: BrowserMessage.TabState, from connection: UUID) {
    let key = TabKey(connection: connection, tabId: state.tabId)
    let now = Date()
    let old = tabs[key]
    var tab = Tab(key: key, state: state, receivedAt: now, startedPlayingAt: old?.startedPlayingAt)
    if state.isPlaying && !(old?.state.isPlaying ?? false) {
      tab.startedPlayingAt = now
    }
    tabs[key] = tab
    publish()
  }

  func closed(tabId: Int, from connection: UUID) {
    tabs[TabKey(connection: connection, tabId: tabId)] = nil
    publish()
  }

  func send(_ command: MediaCommand, for source: NowPlaying.Source) {
    guard let tab = Self.pick(from: Array(tabs.values), source: source),
      let outbound = connections[tab.key.connection]
    else { return }
    outbound.yield(.text(BrowserMessage.encode(command, tabId: tab.key.tabId)))
  }

  /// A playing tab wins, the one that started last; otherwise the most recently updated.
  nonisolated static func pick(from tabs: [Tab], source: NowPlaying.Source) -> Tab? {
    let candidates = tabs.filter { NowPlaying.Source(site: $0.state.site) == source }
    let playing = candidates.filter(\.state.isPlaying)
    if let latest = playing.max(by: {
      ($0.startedPlayingAt ?? .distantPast) < ($1.startedPlayingAt ?? .distantPast)
    }) {
      return latest
    }
    return candidates.max { $0.receivedAt < $1.receivedAt }
  }

  private func publish() {
    for provider in [youtube, youtubeMusic] {
      let tab = Self.pick(from: Array(tabs.values), source: provider.source)
      provider.publish(tab.flatMap { $0.state.nowPlaying(receivedAt: $0.receivedAt) })
    }
  }
}

/// YouTube or YouTube Music as a media source.
@MainActor
final class BrowserProvider: MediaProvider {
  let source: NowPlaying.Source
  var onUpdate: ((NowPlaying?) -> Void)?
  weak var hub: BrowserMediaHub?
  private var last: NowPlaying?

  init(source: NowPlaying.Source) {
    self.source = source
  }

  func start() {}

  func send(_ command: MediaCommand) async {
    hub?.send(command, for: source)
  }

  fileprivate func publish(_ nowPlaying: NowPlaying?) {
    guard nowPlaying != last else { return }
    last = nowPlaying
    onUpdate?(nowPlaying)
  }
}
