import Foundation
import Network

/// `ws://127.0.0.1:<port>/media` for the Chrome extension, on Apple's Network framework. Its
/// HTTP parser reads hostile requests (huge headers, endless frames) in bounded time and
/// memory, which matters here because web pages can reach this port too.
///
/// The handshake needs our extension's Origin and a loopback Host; then `MediaSocketHandler`
/// wants the token within 2 seconds.
struct MediaSocketServer: Sendable {
  let port: UInt16
  let token: String
  let hub: BrowserMediaHub

  /// Tab states are a few hundred bytes; anything far bigger isn't from our extension.
  static let maxMessageSize = 64 * 1024
  /// Each extension (one per Chrome profile) keeps one connection.
  static let maxConnections = 8
  /// The handshake takes milliseconds on the same Mac. Connections that don't finish one in
  /// time (or were turned away) are dropped, so they can't use up `maxConnections`.
  static let handshakeTimeout: DispatchTimeInterval = .seconds(2)

  /// Listens until cancelled or until the listener fails. `onListening` runs once it's ready.
  func run(onListening: @escaping @Sendable () -> Void) async throws {
    let queue = DispatchQueue(label: "io.github.muazfurkan.ljaspnotch.media-socket")
    let listener = try NWListener(using: parameters(queue: queue))
    let state = ListenerState()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        listener.stateUpdateHandler = { newState in
          switch newState {
          case .ready:
            onListening()
          case .failed(let error):
            listener.cancel()
            state.finish(continuation, throwing: error)
          case .cancelled:
            state.finish(continuation, throwing: nil)
          default:
            break
          }
        }
        listener.newConnectionHandler = { connection in
          serve(connection, state: state, queue: queue)
        }
        listener.start(queue: queue)
      }
    } onCancel: {
      listener.cancel()
    }
  }

  private func parameters(queue: DispatchQueue) -> NWParameters {
    let options = NWProtocolWebSocket.Options()
    options.autoReplyPing = true
    options.maximumMessageSize = Self.maxMessageSize
    let port = port
    options.setClientRequestHandler(queue) { _, headers in
      func header(_ name: String) -> String? {
        headers.first { $0.name.lowercased() == name }?.value
      }
      let allowed =
        RequestGuard.checkHost(header("host"), port: port) == nil
        && RequestGuard.checkSocketOrigin(header("origin")) == nil
      return NWProtocolWebSocket.Response(status: allowed ? .accept : .reject, subprotocol: nil)
    }
    let parameters = NWParameters.tcp
    parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
    parameters.requiredLocalEndpoint = .hostPort(
      host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port) ?? .any)
    parameters.allowLocalEndpointReuse = true
    return parameters
  }

  /// Runs on `queue`.
  private func serve(_ connection: NWConnection, state: ListenerState, queue: DispatchQueue) {
    guard state.openConnections < Self.maxConnections else {
      connection.cancel()
      return
    }
    state.openConnections += 1
    let (client, input) = AsyncStream.makeStream(of: MediaSocketMessage.self)
    connection.stateUpdateHandler = { newState in
      switch newState {
      case .failed, .cancelled:
        input.finish()
        if case .cancelled = newState {
          state.openConnections -= 1
        } else {
          connection.cancel()
        }
      default:
        break
      }
    }
    receive(on: connection, into: input)
    connection.start(queue: queue)
    queue.asyncAfter(deadline: .now() + Self.handshakeTimeout) {
      if case .ready = connection.state { return }
      connection.cancel()
    }

    let outbound = MediaSocketHandler(token: token, hub: hub).makeMessages(for: client)
    Task {
      for await message in outbound {
        switch message {
        case .text(let text):
          let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
          let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
          connection.send(
            content: Data(text.utf8), contentContext: context, isComplete: true,
            completion: .idempotent)
        case .close:
          let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
          metadata.closeCode = .protocolCode(.policyViolation)
          let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
          connection.send(
            content: nil, contentContext: context, isComplete: true,
            completion: .contentProcessed { _ in connection.cancel() })
          return
        }
      }
      connection.cancel()
    }
  }

  /// Passes text messages on until the connection closes.
  private func receive(
    on connection: NWConnection, into input: AsyncStream<MediaSocketMessage>.Continuation
  ) {
    connection.receiveMessage { data, context, _, error in
      let metadata =
        context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
        as? NWProtocolWebSocket.Metadata
      // A final message: the other side has closed.
      if error != nil || metadata?.opcode == .close || context?.isFinal == true {
        input.finish()
        return
      }
      if metadata?.opcode == .text, let data {
        input.yield(.text(String(decoding: data, as: UTF8.self)))
      }
      receive(on: connection, into: input)
    }
  }
}

/// The listener's mutable state, touched only on its queue.
private final class ListenerState: @unchecked Sendable {
  var openConnections = 0
  private var isFinished = false

  func finish(_ continuation: CheckedContinuation<Void, Error>, throwing error: Error?) {
    guard !isFinished else { return }
    isFinished = true
    if let error {
      continuation.resume(throwing: error)
    } else {
      continuation.resume()
    }
  }
}
