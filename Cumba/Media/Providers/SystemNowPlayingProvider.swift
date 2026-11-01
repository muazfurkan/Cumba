import Foundation

/// Everything any app plays, from the system's Now Playing: the same source the media keys
/// and Control Center use. Safari, Chrome, YouTube, Spotify, Music and podcasts show up
/// without the browser extension or Automation access, and commands need no permission.
///
/// macOS answers that private API (MediaRemote) only for Apple's own programs, so this runs
/// a small helper from the app bundle inside the system's `/usr/bin/perl`. The helper prints
/// one JSON line per change and takes commands on stdin; it exits when Cumba quits. See
/// `NowPlayingHelper/CumbaNowPlaying.m` and SECURITY.md. When the helper can't run,
/// `onUnavailable` is called and the coordinator falls back to the other providers.
@MainActor
final class SystemNowPlayingProvider {
  /// Called with every change; nil when nothing is playing.
  var onUpdate: ((NowPlaying?) -> Void)?
  var onUnavailable: (() -> Void)?

  private var wantsRunning = false
  private var process: Process?
  private var input: FileHandle?
  private var readTask: Task<Void, Never>?
  private var startedAt: Date?
  private var quickExits = 0
  private var artwork: (id: String, data: Data)?

  static let perl = URL(filePath: "/usr/bin/perl")

  func start() {
    guard !wantsRunning else { return }
    wantsRunning = true
    launch()
  }

  func stop() {
    wantsRunning = false
    readTask?.cancel()
    readTask = nil
    process?.terminate()
    process = nil
    input = nil
    artwork = nil
  }

  func send(_ command: MediaCommand) {
    guard let input else { return }
    let line = Data((SystemNowPlayingMessage.commandLine(for: command) + "\n").utf8)
    Task.detached {
      try? input.write(contentsOf: line)
    }
  }

  private func launch() {
    guard
      let library = Bundle.main.privateFrameworksURL?
        .appending(path: "libCumbaNowPlaying.dylib"),
      let script = Bundle.main.url(forResource: "now-playing", withExtension: "pl")
    else {
      giveUp("the helper is missing from the app")
      return
    }
    let process = Process()
    process.executableURL = Self.perl
    process.arguments = [script.path(percentEncoded: false), library.path(percentEncoded: false)]
    // Nothing from the environment (PERL5OPT, PERL5LIB…) may change what perl runs.
    process.environment = [:]
    let stdin = Pipe()
    let stdout = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = FileHandle.nullDevice
    process.terminationHandler = { [weak self] finished in
      let status = finished.terminationStatus
      Task { @MainActor in self?.ended(status: status) }
    }
    do {
      try process.run()
    } catch {
      giveUp(error.localizedDescription)
      return
    }
    self.process = process
    input = stdin.fileHandleForWriting
    startedAt = Date()
    let output = stdout.fileHandleForReading
    readTask = Task.detached { [weak self] in
      do {
        for try await line in output.bytes.lines {
          guard let message = SystemNowPlayingMessage.decode(line) else { continue }
          await self?.receive(message)
        }
      } catch {
        return
      }
    }
  }

  private func receive(_ message: SystemNowPlayingMessage) {
    if message.error != nil {
      giveUp("MediaRemote is unavailable")
      return
    }
    if let id = message.artworkID, let data = message.artwork {
      artwork = (id, data)
    }
    let data = artwork.flatMap { $0.id == message.artworkID ? $0.data : nil }
    onUpdate?(message.nowPlaying(artwork: data, receivedAt: Date()))
  }

  /// Restarts after a crash, but gives up after three quick exits in a row.
  private func ended(status: Int32) {
    process = nil
    input = nil
    readTask?.cancel()
    readTask = nil
    guard wantsRunning else { return }
    onUpdate?(nil)
    let ranLong = startedAt.map { Date().timeIntervalSince($0) > 60 } ?? false
    quickExits = ranLong ? 0 : quickExits + 1
    guard status != 3, quickExits < 3 else {
      giveUp("the helper exited with status \(status)")
      return
    }
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard let self, self.wantsRunning, self.process == nil else { return }
      self.launch()
    }
  }

  private func giveUp(_ reason: String) {
    Log.media.error("System Now Playing unavailable: \(reason, privacy: .public)")
    stop()
    onUnavailable?()
  }
}

/// One JSON line from the helper.
struct SystemNowPlayingMessage: Decodable, Equatable, Sendable {
  var error: String?
  var bundleID: String?
  var appName: String?
  var title: String?
  var artist: String?
  var album: String?
  var duration: Double?
  var elapsed: Double?
  /// When `elapsed` was measured, in seconds since 1970.
  var timestamp: Double?
  var playing: Bool?
  /// Fingerprint of the artwork; `artwork` itself comes only when it changes.
  var artworkID: String?
  var artwork: Data?

  static func decode(_ line: String) -> Self? {
    try? JSONDecoder().decode(Self.self, from: Data(line.utf8))
  }

  static func commandLine(for command: MediaCommand) -> String {
    switch command {
    case .togglePlayPause: "toggle"
    case .next: "next"
    case .previous: "previous"
    case .seek(let seconds): "seek \(max(0, seconds))"
    }
  }

  /// Any app or web page can set these, so they're capped like the browser's.
  func nowPlaying(artwork: Data?, receivedAt now: Date) -> NowPlaying? {
    func capped(_ text: String?) -> String? {
      text?.nonEmpty.map { String($0.prefix(BrowserMessage.maxTextLength)) }
    }
    guard let title = capped(title) else { return nil }
    return NowPlaying(
      source: Self.source(forBundleID: bundleID), title: title, artist: capped(artist),
      album: capped(album), artworkURL: nil, artworkData: artwork,
      duration: duration.flatMap { $0 > 0 ? $0 : nil }, position: elapsed,
      positionTimestamp: timestamp.map(Date.init(timeIntervalSince1970:)) ?? now,
      isPlaying: playing ?? false, appName: appName?.nonEmpty)
  }

  /// Chrome's web apps for YouTube and YouTube Music have fixed IDs.
  private static let youtubeApp = ".app.agimnkijcaahngcdmfeangaknmldooml"
  private static let youtubeMusicApp = ".app.cinhimbnkkaeohfgghhklpknlkffjgod"
  private static let browsers = [
    "com.apple.Safari", "com.google.Chrome", "company.thebrowser.", "com.microsoft.edgemac",
    "com.brave.Browser", "org.mozilla.firefox", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
    "app.zen-browser.",
  ]

  static func source(forBundleID id: String?) -> NowPlaying.Source {
    guard let id else { return .otherApp }
    if id == "com.spotify.client" { return .spotify }
    if id == "com.apple.Music" { return .appleMusic }
    if id.hasSuffix(youtubeApp) { return .youtube }
    if id.hasSuffix(youtubeMusicApp) { return .youtubeMusic }
    if browsers.contains(where: { id.hasPrefix($0) }) { return .browser }
    return .otherApp
  }
}

extension String {
  fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}
