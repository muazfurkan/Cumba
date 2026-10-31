import FlyingFox
import Foundation
import Observation

/// The app's two local servers. Each runs only while its feature is in use:
/// - HTTP/WebSocket on 127.0.0.1 for the Chrome extension (`/media`), checking Host,
///   Origin and the extension token. Only while turned on in Settings > Connections.
/// - HTTP on a Unix socket for Claude Code hooks (`/claude/hook`), checking the hook token.
///   Only while the hooks are installed. The socket's folder is readable only by this user,
///   so no other user or app can answer Claude Code in the app's place, not even while the
///   app is closed.
/// Both restart on their own after a failure.
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

  /// `~/Library/Application Support/ljaspNotch/hook.sock`
  nonisolated static var hookSocketURL: URL {
    let base =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support")
    return base.appending(path: "ljaspNotch/hook.sock")
  }

  /// The extension server.
  private(set) var status = Status.stopped
  /// The Claude Code socket; `.running(port: 0)` while listening.
  private(set) var hookStatus = Status.stopped
  /// Written into `~/.claude/settings.json` by the hook installer. Empty until read.
  private(set) var hookToken = ""
  /// Pasted into the Chrome extension's options. Empty until read.
  private(set) var extensionToken = ""
  let browserHub: BrowserMediaHub
  let claude: ClaudeCodeService

  @ObservationIgnored private var mediaTask: Task<Void, Never>?
  @ObservationIgnored private var hookTask: Task<Void, Never>?

  init(browserHub: BrowserMediaHub, claude: ClaudeCodeService) {
    self.browserHub = browserHub
    self.claude = claude
  }

  /// Reads both tokens from the Keychain; the servers start only after this.
  func loadTokens() async {
    do {
      (hookToken, extensionToken) = try await Task.detached {
        (try TokenStore.loadOrCreate(.hooks), try TokenStore.loadOrCreate(.browserExtension))
      }.value
    } catch {
      status = .failed(String(localized: "The token couldn't be read from the Keychain."))
      hookStatus = status
      Log.server.error("Token unavailable: \(String(describing: error), privacy: .public)")
    }
  }

  /// Starts the extension server on `port`, or restarts it there.
  func startExtensionServer(port: UInt16) {
    stopExtensionServer()
    guard !extensionToken.isEmpty else { return }
    let token = extensionToken
    let hub = browserHub
    let make: @MainActor () async throws -> HTTPServer = {
      let server = HTTPServer(
        address: try sockaddr_in.inet(ip4: "127.0.0.1", port: port),
        timeout: Self.requestTimeout, logger: .disabled)
      await server.appendRoute(
        "GET /media", to: MediaSocketRoute(port: port, token: token, hub: hub))
      return server
    }
    mediaTask = supervise(
      running: .running(port: port),
      failure: String(
        localized: "Port \(String(port)) is in use or unavailable. Choose another port.",
        comment: "Local server error"),
      update: { [weak self] in self?.status = $0 }, make: make)
  }

  func stopExtensionServer() {
    mediaTask?.cancel()
    mediaTask = nil
    status = .stopped
  }

  /// Starts the hook socket unless it already runs.
  func startHookServer() {
    guard hookTask == nil, !hookToken.isEmpty else { return }
    let token = hookToken
    let claude = claude
    let make: @MainActor () async throws -> HTTPServer = {
      let path = try await Task.detached { try Self.prepareHookSocket() }.value
      let server = HTTPServer(
        address: sockaddr_un.unix(path: path), timeout: Self.requestTimeout, logger: .disabled)
      await server.appendRoute(
        "POST /claude/hook", to: ClaudeHookRoute(token: token, service: claude))
      return server
    }
    hookTask = supervise(
      running: .running(port: 0),
      failure: String(localized: "The Claude Code socket couldn't be opened."),
      update: { [weak self] in self?.hookStatus = $0 }, make: make)
  }

  func stopHookServer() {
    hookTask?.cancel()
    hookTask = nil
    hookStatus = .stopped
  }

  /// New extension token; the extension needs it pasted again.
  func regenerateExtensionToken(port: UInt16) async {
    do {
      extensionToken = try await Task.detached { try TokenStore.regenerate(.browserExtension) }
        .value
    } catch {
      Log.server.error("Token regeneration failed: \(String(describing: error), privacy: .public)")
      return
    }
    if mediaTask != nil {
      startExtensionServer(port: port)
    }
  }

  /// Runs a server and starts it again after a failure, waiting longer each time (up to a
  /// minute). Cancelling the task stops the server.
  private func supervise(
    running: Status, failure: String, update: @escaping @MainActor (Status) -> Void,
    make: @escaping @MainActor () async throws -> HTTPServer
  ) -> Task<Void, Never> {
    Task {
      var delay = Duration.seconds(2)
      while !Task.isCancelled {
        do {
          let server = try await make()
          let watcher = Task {
            if (try? await server.waitUntilListening(timeout: 5)) != nil {
              update(running)
            }
          }
          defer { watcher.cancel() }
          try await server.run()
        } catch is CancellationError {
          return
        } catch {
          guard !Task.isCancelled else { return }
          Log.server.error("Server failed: \(String(describing: error), privacy: .public)")
          update(.failed(failure))
        }
        do {
          try await Task.sleep(for: delay)
        } catch {
          return
        }
        delay = min(delay * 2, .seconds(60))
      }
    }
  }

  /// Creates the private folder and removes a stale socket file. Returns the socket path.
  nonisolated static func prepareHookSocket() throws -> String {
    let url = hookSocketURL
    let path = url.path(percentEncoded: false)
    // sockaddr_un holds at most 104 bytes.
    guard path.utf8.count < 104 else { throw CocoaError(.fileWriteInvalidFileName) }
    let folder = url.deletingLastPathComponent().path(percentEncoded: false)
    let manager = FileManager.default
    try manager.createDirectory(
      atPath: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder)
    unlink(path)
    return path
  }
}
