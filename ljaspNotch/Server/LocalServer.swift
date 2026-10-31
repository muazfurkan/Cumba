import FlyingFox
import Foundation
import Observation

/// HTTP/WebSocket server on 127.0.0.1 for the Chrome extension and Claude Code hooks
/// (SPEC § 12). Never listens on other interfaces; every route checks Host and the token.
@MainActor
@Observable
final class LocalServer {
  enum Status: Equatable, Sendable {
    case stopped
    case running(port: UInt16)
    case failed(String)
  }

  static let defaultPort: UInt16 = 47823
  /// Long enough for a held Claude Code permission request (hook timeout 300 s).
  static let requestTimeout: TimeInterval = 310

  private(set) var status = Status.stopped
  /// Empty until the Keychain has been read.
  private(set) var token = ""
  let browserHub: BrowserMediaHub
  /// Extra routes added by other features, e.g. Claude Code hooks.
  @ObservationIgnored var extraRoutes: [(route: HTTPRoute, handler: any HTTPHandler)] = []

  @ObservationIgnored private var server: HTTPServer?
  @ObservationIgnored private var runTask: Task<Void, Never>?

  init(browserHub: BrowserMediaHub) {
    self.browserHub = browserHub
  }

  func start(port: UInt16) async {
    await stop()
    do {
      token = try await Task.detached { try TokenStore.loadOrCreate() }.value
    } catch {
      status = .failed(String(localized: "The token couldn't be read from the Keychain."))
      Log.server.error("Token unavailable: \(String(describing: error), privacy: .public)")
      return
    }
    await listen(on: port)
  }

  func stop() async {
    runTask?.cancel()
    runTask = nil
    if let server {
      await server.stop(timeout: 1)
    }
    server = nil
    status = .stopped
  }

  /// New token; the extension and the hooks need it again.
  func regenerateToken(port: UInt16) async {
    do {
      token = try await Task.detached { try TokenStore.regenerate() }.value
    } catch {
      Log.server.error("Token regeneration failed: \(String(describing: error), privacy: .public)")
      return
    }
    await stop()
    await listen(on: port)
  }

  private func listen(on port: UInt16) async {
    let address: sockaddr_in
    do {
      address = try .inet(ip4: "127.0.0.1", port: port)
    } catch {
      status = .failed(String(localized: "Invalid port."))
      return
    }
    let server = HTTPServer(address: address, timeout: Self.requestTimeout, logger: .disabled)
    await server.appendRoute(
      "GET /media", to: MediaSocketRoute(port: port, token: token, hub: browserHub))
    for extra in extraRoutes {
      await server.appendRoute(extra.route, to: extra.handler)
    }
    self.server = server
    runTask = Task { [weak self] in
      do {
        try await server.run()
      } catch is CancellationError {
        return
      } catch {
        Log.server.error("Server stopped: \(String(describing: error), privacy: .public)")
        self?.status = .failed(
          String(
            localized: "Port \(String(port)) is in use or unavailable. Choose another port.",
            comment: "Local server error"))
      }
    }
    do {
      try await server.waitUntilListening(timeout: 3)
      status = .running(port: port)
      Log.server.info("Listening on 127.0.0.1:\(port, privacy: .public)")
    } catch {
      if case .running = status {
        return
      }
      if case .stopped = status {
        status = .failed(
          String(
            localized: "Port \(String(port)) is in use or unavailable. Choose another port.",
            comment: "Local server error"))
      }
    }
  }
}
