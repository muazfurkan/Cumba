import Foundation
import Testing

@testable import Cumba

struct RequestGuardTests {
  @Test(arguments: ["127.0.0.1:47823", "localhost:47823", "LOCALHOST:47823"])
  func loopbackHostsAreAllowed(host: String) {
    #expect(RequestGuard.checkHost(host, port: 47823) == nil)
  }

  @Test(arguments: [nil, "", "evil.example:47823", "127.0.0.1:80", "127.0.0.1", "[::1]:47823"])
  func otherHostsAreRejected(host: String?) {
    #expect(RequestGuard.checkHost(host, port: 47823) == .badHost)
  }

  @Test func socketNeedsOurExtensionOrigin() {
    #expect(RequestGuard.checkSocketOrigin(RequestGuard.extensionOrigin) == nil)
    #expect(RequestGuard.checkSocketOrigin("chrome-extension://abcdef") == .badOrigin)
    #expect(RequestGuard.checkSocketOrigin(nil) == .badOrigin)
    #expect(RequestGuard.checkSocketOrigin("https://www.youtube.com") == .badOrigin)
  }

  @Test func tokenMustMatchExactly() {
    let token = String(repeating: "a", count: 64)
    #expect(RequestGuard.checkToken(token, expected: token) == nil)
    #expect(RequestGuard.checkToken(nil, expected: token) == .badToken)
    #expect(RequestGuard.checkToken(String(token.dropLast()), expected: token) == .badToken)
    #expect(RequestGuard.checkToken(token + "a", expected: token) == .badToken)
    #expect(RequestGuard.checkToken("", expected: "") == .badToken)
  }
}

struct BrowserMessageTests {
  @Test func decodesTheSpecMessages() throws {
    #expect(
      BrowserMessage.decode(#"{ "type": "hello", "version": 1, "token": "t" }"#)
        == .hello(version: 1, token: "t"))
    #expect(BrowserMessage.decode(#"{ "type": "closed", "tabId": 812 }"#) == .closed(tabId: 812))
    let state = try #require(
      BrowserMessage.decode(
        #"{ "type": "state", "tabId": 812, "site": "youtubeMusic", "title": "Song Title", "artist": "Artist", "album": "Album", "artworkUrl": "https://lh3.example/a.jpg", "videoId": "abc123", "duration": 215.3, "position": 42.1, "isPlaying": true, "sentAt": 1793380000000 }"#
      ))
    guard case .state(let tab) = state else {
      Issue.record("Expected a state message")
      return
    }
    let nowPlaying = try #require(
      tab.nowPlaying(receivedAt: Date(timeIntervalSince1970: 1_793_380_000)))
    #expect(nowPlaying.source == .youtubeMusic)
    #expect(nowPlaying.position == 42.1)
    #expect(nowPlaying.artworkURL?.scheme == "https")
  }

  @Test(arguments: [
    "not json", #"{ "type": "nope" }"#, #"{ "type": "state", "tabId": 1 }"#,
    #"{ "type": "state", "tabId": 1, "site": "vimeo", "title": "x", "isPlaying": true }"#,
  ])
  func rejectsInvalidMessages(text: String) {
    #expect(BrowserMessage.decode(text) == nil)
  }

  @Test func cutsLongTextAndDropsUnsafeArtwork() throws {
    let long = String(repeating: "x", count: 5000)
    let text =
      #"{ "type": "state", "tabId": 1, "site": "youtube", "title": "\#(long)", "artworkUrl": "javascript:alert(1)", "isPlaying": false }"#
    guard case .state(let tab) = try #require(BrowserMessage.decode(text)) else { return }
    #expect(tab.title.count == BrowserMessage.maxTextLength)
    #expect(tab.nowPlaying(receivedAt: .now)?.artworkURL == nil)
  }

  @Test func encodesCommands() {
    #expect(
      BrowserMessage.encode(.seek(90), tabId: 812)
        == #"{"action":"seek","position":90,"tabId":812,"type":"command"}"#)
    #expect(BrowserMessage.encode(.togglePlayPause, tabId: 1).contains(#""action":"toggle""#))
  }
}

@MainActor
struct BrowserMediaHubTests {
  private func state(_ tabId: Int, site: String = "youtube", playing: Bool)
    -> BrowserMessage
    .TabState
  {
    BrowserMessage.TabState(tabId: tabId, site: site, title: "T\(tabId)", isPlaying: playing)
  }

  @Test func playingTabThatStartedLastWins() async throws {
    let hub = BrowserMediaHub()
    var shown: [NowPlaying?] = []
    hub.youtube.onUpdate = { shown.append($0) }
    let connection = UUID()
    hub.receive(state(1, playing: true), from: connection)
    try await Task.sleep(for: .milliseconds(5))
    hub.receive(state(2, playing: true), from: connection)
    hub.receive(state(3, playing: false), from: connection)
    #expect(shown.last??.title == "T2")
    hub.closed(tabId: 2, from: connection)
    #expect(shown.last??.title == "T1")
    hub.disconnected(connection)
    #expect(shown.last! == nil)
  }

  @Test func sitesAreSeparate() {
    let hub = BrowserMediaHub()
    var music: NowPlaying?
    hub.youtubeMusic.onUpdate = { music = $0 }
    hub.receive(state(1, site: "youtube", playing: true), from: UUID())
    #expect(music == nil)
    hub.receive(state(2, site: "youtubeMusic", playing: false), from: UUID())
    #expect(music?.title == "T2")
  }
}

@MainActor
struct MediaSocketHandlerTests {
  private let token = String(repeating: "b", count: 64)

  @Test func wrongTokenClosesTheConnection() async throws {
    let hub = BrowserMediaHub()
    let (client, input) = AsyncStream.makeStream(of: MediaSocketMessage.self)
    let outbound = MediaSocketHandler(token: token, hub: hub).makeMessages(for: client)
    input.yield(.text(#"{ "type": "hello", "version": 1, "token": "wrong" }"#))
    var iterator = outbound.makeAsyncIterator()
    #expect(await iterator.next() == .close)
    #expect(hub.connectionCount == 0)
    input.finish()
  }

  @Test func anythingBeforeHelloClosesTheConnection() async throws {
    let hub = BrowserMediaHub()
    var shown: NowPlaying?
    hub.youtube.onUpdate = { shown = $0 }
    let (client, input) = AsyncStream.makeStream(of: MediaSocketMessage.self)
    let outbound = MediaSocketHandler(token: token, hub: hub).makeMessages(for: client)
    input.yield(
      .text(#"{ "type": "state", "tabId": 1, "site": "youtube", "title": "x", "isPlaying": true }"#)
    )
    var iterator = outbound.makeAsyncIterator()
    #expect(await iterator.next() == .close)
    #expect(shown == nil)
    #expect(hub.connectionCount == 0)
    input.finish()
  }

  @Test func validHelloConnectsAndForwardsStates() async throws {
    let hub = BrowserMediaHub()
    var shown: NowPlaying?
    hub.youtube.onUpdate = { shown = $0 }
    let (client, input) = AsyncStream.makeStream(of: MediaSocketMessage.self)
    _ = MediaSocketHandler(token: token, hub: hub).makeMessages(for: client)
    input.yield(.text(#"{ "type": "hello", "version": 1, "token": "\#(token)" }"#))
    input.yield(
      .text(#"{ "type": "state", "tabId": 1, "site": "youtube", "title": "x", "isPlaying": true }"#)
    )
    for _ in 0..<50 where shown == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(hub.connectionCount == 1)
    #expect(shown?.title == "x")
    input.finish()
    for _ in 0..<50 where hub.connectionCount > 0 {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(hub.connectionCount == 0)
  }
}

/// The real listener on a free port, with URLSession as the extension.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MediaSocketServerTests {
  private let token = String(repeating: "c", count: 64)
  private let extensionOrigin = RequestGuard.extensionOrigin

  private func start(_ hub: BrowserMediaHub) async -> (port: UInt16, task: Task<Void, Error>) {
    let port = UInt16.random(in: 50_000...59_000)
    let server = MediaSocketServer(port: port, token: token, hub: hub)
    let (ready, signal) = AsyncStream.makeStream(of: Void.self)
    // If the port can't be opened, the stream ends and the test fails instead of waiting.
    let task = Task {
      defer { signal.finish() }
      try await server.run { signal.yield() }
    }
    var iterator = ready.makeAsyncIterator()
    _ = await iterator.next()
    return (port, task)
  }

  private func connect(port: UInt16, origin: String) throws -> URLSessionWebSocketTask {
    var request = URLRequest(url: try #require(URL(string: "ws://127.0.0.1:\(port)/media")))
    request.setValue(origin, forHTTPHeaderField: "Origin")
    let socket = URLSession(configuration: .ephemeral).webSocketTask(with: request)
    socket.resume()
    return socket
  }

  @Test func ourExtensionWithTheTokenGetsThrough() async throws {
    let hub = BrowserMediaHub()
    var shown: NowPlaying?
    hub.youtube.onUpdate = { shown = $0 }
    let (port, task) = await start(hub)
    defer { task.cancel() }
    let socket = try connect(port: port, origin: extensionOrigin)
    try await socket.send(.string(#"{ "type": "hello", "version": 1, "token": "\#(token)" }"#))
    try await socket.send(
      .string(
        #"{ "type": "state", "tabId": 1, "site": "youtube", "title": "x", "isPlaying": true }"#))
    for _ in 0..<100 where shown == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(shown?.title == "x")
    socket.cancel(with: .goingAway, reason: nil)
  }

  @Test(arguments: ["https://evil.example", "chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"])
  func otherOriginsAreTurnedAway(origin: String) async throws {
    let hub = BrowserMediaHub()
    let (port, task) = await start(hub)
    defer { task.cancel() }
    let socket = try connect(port: port, origin: origin)
    await #expect(throws: (any Error).self) { try await socket.receive() }
    #expect(hub.connectionCount == 0)
  }

  @Test func aWrongTokenIsClosed() async throws {
    let hub = BrowserMediaHub()
    let (port, task) = await start(hub)
    defer { task.cancel() }
    let socket = try connect(port: port, origin: extensionOrigin)
    try await socket.send(.string(#"{ "type": "hello", "version": 1, "token": "wrong" }"#))
    await #expect(throws: (any Error).self) { try await socket.receive() }
    #expect(socket.closeCode == .policyViolation)
    #expect(hub.connectionCount == 0)
  }
}
