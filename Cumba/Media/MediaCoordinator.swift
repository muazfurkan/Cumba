import Foundation
import Observation

/// Combines all media providers into what the media widget shows. The progress
/// bar is computed locally from the last known position, not by asking players.
///
/// By default everything comes from the system's Now Playing, which covers every app.
/// With that turned off, or when it can't run, Spotify and Music are read with AppleScript
/// and browsers through the extension.
@MainActor
@Observable
final class MediaCoordinator {
  private(set) var current: NowPlaying?
  private(set) var availableSources: [NowPlaying.Source] = []
  /// Latest command failure per source, e.g. denied Automation access.
  private(set) var failures: [NowPlaying.Source: AppleScriptRunner.Failure] = [:]

  /// Sources turned off in Settings. Their updates are ignored and Spotify and Music get
  /// no AppleScript.
  var disabledSources: Set<NowPlaying.Source> = [] {
    didSet {
      defaults?.set(disabledSources.map(\.rawValue).sorted(), forKey: Self.disabledKey)
      applyDisabledSources()
    }
  }

  /// Reads every app through the system's Now Playing; off uses Spotify, Music and the
  /// browser extension.
  var usesSystemNowPlaying: Bool {
    didSet {
      defaults?.set(usesSystemNowPlaying, forKey: Self.systemKey)
      applyMode()
    }
  }
  /// The system's Now Playing couldn't be read on this Mac, so the other sources are used.
  private(set) var systemNowPlayingFailed = false

  @ObservationIgnored private var selection = MediaSelection()
  @ObservationIgnored private var providers: [any MediaProvider]
  @ObservationIgnored private let system: SystemNowPlayingProvider?
  @ObservationIgnored private var isStarted = false
  @ObservationIgnored private var startedProviders = false
  @ObservationIgnored private var expiryTask: Task<Void, Never>?
  @ObservationIgnored private let defaults: UserDefaults?

  private static let disabledKey = "media.disabledSources"
  private static let systemKey = "media.usesSystemNowPlaying"

  /// - Parameters:
  ///   - system: Reads every app; `nil` uses only `providers`.
  ///   - defaults: Where the source choice is saved; `nil` keeps it in memory.
  init(
    providers: [any MediaProvider], system: SystemNowPlayingProvider? = nil,
    defaults: UserDefaults? = nil
  ) {
    self.providers = providers
    self.system = system
    self.defaults = defaults
    let saved = defaults?.stringArray(forKey: Self.disabledKey) ?? []
    disabledSources = Set(saved.compactMap(NowPlaying.Source.init(rawValue:)))
    usesSystemNowPlaying = defaults?.object(forKey: Self.systemKey) as? Bool ?? true
  }

  static func standard() -> MediaCoordinator {
    MediaCoordinator(
      providers: [
        ScriptablePlayerProvider(adapter: SpotifyAdapter()),
        ScriptablePlayerProvider(adapter: MusicAdapter()),
      ], system: SystemNowPlayingProvider(), defaults: .standard)
  }

  /// True while the system's Now Playing is the source of everything.
  var isUsingSystemNowPlaying: Bool {
    usesSystemNowPlaying && system != nil && !systemNowPlayingFailed
  }

  private func applyDisabledSources() {
    for provider in providers {
      (provider as? ScriptablePlayerProvider)?.isEnabled =
        !isUsingSystemNowPlaying && !disabledSources.contains(provider.source)
    }
    for source in disabledSources {
      selection.update(nil, for: source, at: Date())
    }
    refresh()
  }

  func start() {
    for provider in providers {
      wire(provider)
    }
    system?.onUpdate = { [weak self] nowPlaying in
      self?.receiveSystem(nowPlaying)
    }
    system?.onUnavailable = { [weak self] in
      self?.systemNowPlayingFailed = true
      self?.applyMode()
    }
    isStarted = true
    applyMode()
  }

  /// Switches between the system's Now Playing and the other providers. Those start only
  /// when first needed, so AppleScript never runs while the system covers everything.
  private func applyMode() {
    guard isStarted else { return }
    selection = MediaSelection()
    if isUsingSystemNowPlaying {
      system?.start()
    } else {
      system?.stop()
      if !startedProviders {
        startedProviders = true
        for provider in providers {
          provider.start()
        }
      }
    }
    applyDisabledSources()
  }

  private func wire(_ provider: any MediaProvider) {
    let source = provider.source
    provider.onUpdate = { [weak self] nowPlaying in
      self?.receive(nowPlaying, from: source)
    }
    if let scriptable = provider as? ScriptablePlayerProvider {
      scriptable.onFailureChange = { [weak self] failure in
        self?.failures[source] = failure
      }
    }
  }

  /// Adds a provider later, e.g. the browser provider once the local server runs.
  func add(_ provider: any MediaProvider) {
    providers.append(provider)
    wire(provider)
    provider.start()
  }

  func send(_ command: MediaCommand) async {
    if isUsingSystemNowPlaying {
      system?.send(command)
      return
    }
    guard let source = current?.source,
      let provider = providers.first(where: { $0.source == source })
    else { return }
    await provider.send(command)
  }

  /// Shows a source picked by hand while it has something to show.
  func pin(_ source: NowPlaying.Source?) {
    selection.pinnedSource = source
    refresh()
  }

  func provider(for source: NowPlaying.Source) -> (any MediaProvider)? {
    providers.first { $0.source == source }
  }

  func receive(_ nowPlaying: NowPlaying?, from source: NowPlaying.Source) {
    guard !isUsingSystemNowPlaying else { return }
    selection.update(disabledSources.contains(source) ? nil : nowPlaying, for: source, at: Date())
    refresh()
  }

  /// The system reports one app at a time, and commands reach only that app, so it
  /// replaces whatever was shown before.
  func receiveSystem(_ nowPlaying: NowPlaying?) {
    guard isUsingSystemNowPlaying else { return }
    let now = Date()
    for source in NowPlaying.Source.allCases where source != nowPlaying?.source {
      selection.update(nil, for: source, at: now)
    }
    if let nowPlaying {
      let shown = disabledSources.contains(nowPlaying.source) ? nil : nowPlaying
      selection.update(shown, for: nowPlaying.source, at: now)
    }
    refresh()
  }

  private func refresh() {
    let now = Date()
    let next = selection.current(at: now)
    if next != current {
      current = next
    }
    let sources = selection.availableSources(at: now)
    if sources != availableSources {
      availableSources = sources
    }
    scheduleExpiry(after: now)
  }

  /// A paused player disappears after 10 minutes; wake up once at that moment.
  private func scheduleExpiry(after now: Date) {
    expiryTask?.cancel()
    guard let expiry = selection.nextExpiry(after: now) else { return }
    expiryTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(expiry.timeIntervalSince(now) + 0.5))
      } catch {
        return
      }
      self?.refresh()
    }
  }
}
