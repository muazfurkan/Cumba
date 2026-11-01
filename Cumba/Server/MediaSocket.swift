import Foundation

/// A WebSocket message to or from the Chrome extension.
enum MediaSocketMessage: Equatable, Sendable {
  case text(String)
  /// Close the connection: it broke the rules (policy violation).
  case close
}

/// The media socket's rules, apart from the transport (`MediaSocketServer`): the first message
/// must be a `hello` with the token, sent within 2 seconds (the extension sends it as soon as
/// it connects). Anything else closes the connection at once.
struct MediaSocketHandler {
  let token: String
  let hub: BrowserMediaHub

  static let helloTimeout = Duration.seconds(2)

  /// Reads the extension's messages from `client` and returns the app's messages to it.
  func makeMessages(for client: AsyncStream<MediaSocketMessage>) -> AsyncStream<
    MediaSocketMessage
  > {
    let (outbound, continuation) = AsyncStream.makeStream(of: MediaSocketMessage.self)
    let id = UUID()
    let token = token
    let hub = hub

    // Close connections that don't say hello in time, including handshakes that were turned
    // away: Network keeps those open without telling.
    Task {
      try? await Task.sleep(for: Self.helloTimeout)
      if await !hub.isConnected(id) {
        continuation.yield(.close)
        continuation.finish()
      }
    }

    Task {
      var authenticated = false
      for await message in client {
        let decoded: BrowserMessage? =
          if case .text(let text) = message { BrowserMessage.decode(text) } else { nil }
        if !authenticated {
          guard case .hello(_, let provided) = decoded,
            RequestGuard.checkToken(provided, expected: token) == nil
          else {
            Log.media.error("Rejected a browser connection without a valid token")
            continuation.yield(.close)
            break
          }
          authenticated = true
          await hub.connected(id, outbound: continuation)
          continue
        }
        guard let decoded else { continue }
        switch decoded {
        case .state(let state):
          await hub.receive(state, from: id)
        case .closed(let tabId):
          await hub.closed(tabId: tabId, from: id)
        case .ping, .hello:
          break
        }
      }
      await hub.disconnected(id)
      continuation.finish()
    }
    return outbound
  }
}
