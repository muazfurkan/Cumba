import FlyingFox
import Foundation

/// `GET /media`: WebSocket for the Chrome extension. The handshake needs an extension
/// Origin and a loopback Host; the first message must be a `hello` with the token, sent
/// within 5 seconds. Anything else closes the connection (SPEC § 12).
struct MediaSocketRoute: HTTPHandler {
  let port: UInt16
  let token: String
  let hub: BrowserMediaHub

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    if RequestGuard.checkHost(request.headers[.host], port: port) != nil
      || RequestGuard.checkSocketOrigin(request.headers[HTTPHeader("Origin")]) != nil
    {
      return HTTPResponse(statusCode: .forbidden)
    }
    let socket = WebSocketHTTPHandler.webSocket(MediaSocketHandler(token: token, hub: hub))
    return try await socket.handleRequest(request)
  }
}

struct MediaSocketHandler: WSMessageHandler {
  let token: String
  let hub: BrowserMediaHub

  func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
    let (outbound, continuation) = AsyncStream.makeStream(of: WSMessage.self)
    let id = UUID()
    let token = token
    let hub = hub

    // Close connections that don't say hello in time.
    Task {
      try? await Task.sleep(for: .seconds(5))
      if await !hub.isConnected(id) {
        continuation.yield(.close(.policyViolation))
        continuation.finish()
      }
    }

    Task {
      var authenticated = false
      for await message in client {
        guard case .text(let text) = message, let decoded = BrowserMessage.decode(text) else {
          continue
        }
        if !authenticated {
          guard case .hello(_, let provided) = decoded,
            RequestGuard.checkToken(provided, expected: token) == nil
          else {
            Log.media.error("Rejected a browser connection without a valid token")
            continuation.yield(.close(.policyViolation))
            break
          }
          authenticated = true
          await hub.connected(id, outbound: continuation)
          continue
        }
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
