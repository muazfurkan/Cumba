import AppKit

/// Spotify or Music: listens to the player's distributed notifications and uses
/// AppleScript for controls and for details the notification lacks (position, artwork).
/// AppleScript is only sent while the player runs and Automation access is granted.
@MainActor
final class ScriptablePlayerProvider: MediaProvider {
  let adapter: any PlayerAdapter
  var onUpdate: ((NowPlaying?) -> Void)?
  /// The last failure of a command, e.g. denied Automation access. Cleared on success.
  private(set) var lastFailure: AppleScriptRunner.Failure?
  var onFailureChange: ((AppleScriptRunner.Failure?) -> Void)?
  /// Off when the source is turned off in Settings: no AppleScript is sent then.
  var isEnabled = true

  private let runner: AppleScriptRunner
  private var observers: [NSObjectProtocol] = []
  private var current: NowPlaying?
  private var detailsTask: Task<Void, Never>?

  var source: NowPlaying.Source { adapter.source }

  init(adapter: any PlayerAdapter, runner: AppleScriptRunner = .shared) {
    self.adapter = adapter
    self.runner = runner
  }

  func start() {
    let adapter = adapter
    let bundleID = adapter.bundleID
    observers.append(
      DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name(adapter.notificationName), object: nil, queue: .main
      ) { [weak self] notification in
        let nowPlaying = adapter.parse(notification: notification.userInfo ?? [:], at: Date())
        MainActor.assumeIsolated { self?.received(nowPlaying) }
      })
    observers.append(
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
      ) { [weak self] notification in
        let app =
          notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.bundleIdentifier == bundleID else { return }
        MainActor.assumeIsolated { self?.received(nil) }
      })
    // A player that is already playing posts nothing until something changes.
    refreshFromScript()
  }

  func send(_ command: MediaCommand) async {
    let script = adapter.commandScript(command)
    do {
      try await runner.run(script, in: adapter.bundleID) { _ in () }
      setFailure(nil)
      if case .seek(let position) = command, var current {
        current.position = position
        current.positionTimestamp = Date()
        received(current, fetchDetails: false)
      }
      // Music doesn't post a notification for every command; read the state back.
      refreshFromScript()
    } catch {
      setFailure(error)
      Log.media.error(
        "\(self.source.rawValue, privacy: .public) command failed: \(String(describing: error), privacy: .public)"
      )
    }
  }

  /// Reads the full state, e.g. at launch or after a command. Quietly does nothing without
  /// permission or when the player isn't running.
  func refreshFromScript() {
    guard isEnabled else { return }
    let adapter = adapter
    Task {
      let state = try? await runner.run(adapter.stateScript, in: adapter.bundleID) { descriptor in
        adapter.parse(state: descriptor, at: Date())
      }
      guard let state else { return }
      received(state)
    }
  }

  private func received(_ nowPlaying: NowPlaying?, fetchDetails: Bool = true) {
    guard isEnabled || nowPlaying == nil else { return }
    var nowPlaying = nowPlaying
    // Keep artwork already fetched for this track.
    if let previous = current, var track = nowPlaying, track.isSameTrack(as: previous) {
      track.artworkURL = track.artworkURL ?? previous.artworkURL
      track.artworkData = track.artworkData ?? previous.artworkData
      if track.position == nil {
        track.position = previous.currentPosition()
      }
      nowPlaying = track
    }
    let isNewTrack = !(nowPlaying?.isSameTrack(as: current) ?? true)
    current = nowPlaying
    onUpdate?(nowPlaying)
    if fetchDetails, let nowPlaying {
      fetchMissingDetails(for: nowPlaying, isNewTrack: isNewTrack)
    }
  }

  /// Position (Music) and artwork (both), when Automation access allows it.
  private func fetchMissingDetails(for nowPlaying: NowPlaying, isNewTrack: Bool) {
    let needsArtwork = isNewTrack || (nowPlaying.artworkURL == nil && nowPlaying.artworkData == nil)
    let needsPosition = nowPlaying.position == nil
    guard needsArtwork || needsPosition else { return }
    let adapter = adapter
    detailsTask?.cancel()
    detailsTask = Task {
      var updated = nowPlaying
      if needsPosition,
        let state = try? await runner.run(
          adapter.stateScript, in: adapter.bundleID,
          parse: { adapter.parse(state: $0, at: Date()) }),
        state.isSameTrack(as: nowPlaying)
      {
        updated.position = state.position
        updated.positionTimestamp = state.positionTimestamp
      }
      if needsArtwork,
        let artwork = try? await runner.run(
          adapter.artworkScript, in: adapter.bundleID,
          parse: { descriptor -> NowPlaying in
            var copy = nowPlaying
            adapter.applyArtwork(descriptor, to: &copy)
            return copy
          })
      {
        updated.artworkURL = artwork.artworkURL
        updated.artworkData = artwork.artworkData
      }
      guard !Task.isCancelled, updated != nowPlaying, updated.isSameTrack(as: current) else {
        return
      }
      current = updated
      onUpdate?(updated)
    }
  }

  private func setFailure(_ failure: AppleScriptRunner.Failure?) {
    guard failure != lastFailure else { return }
    lastFailure = failure
    onFailureChange?(failure)
  }
}
