import Foundation
import Observation

/// Combines all media providers into what the media widget shows. The progress
/// bar is computed locally from the last known position, not by asking players.
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

  @ObservationIgnored private var selection = MediaSelection()
  @ObservationIgnored private var providers: [any MediaProvider]
  @ObservationIgnored private var expiryTask: Task<Void, Never>?
  @ObservationIgnored private let defaults: UserDefaults?

  private static let disabledKey = "media.disabledSources"

  /// - Parameter defaults: Where the source choice is saved; `nil` keeps it in memory.
  init(providers: [any MediaProvider], defaults: UserDefaults? = nil) {
    self.providers = providers
    self.defaults = defaults
    let saved = defaults?.stringArray(forKey: Self.disabledKey) ?? []
    disabledSources = Set(saved.compactMap(NowPlaying.Source.init(rawValue:)))
  }

  static func standard() -> MediaCoordinator {
    MediaCoordinator(
      providers: [
        ScriptablePlayerProvider(adapter: SpotifyAdapter()),
        ScriptablePlayerProvider(adapter: MusicAdapter()),
      ], defaults: .standard)
  }

  private func applyDisabledSources() {
    for provider in providers {
      (provider as? ScriptablePlayerProvider)?.isEnabled =
        !disabledSources.contains(provider.source)
    }
    for source in disabledSources {
      selection.update(nil, for: source, at: Date())
    }
    refresh()
  }

  func start() {
    applyDisabledSources()
    for provider in providers {
      let source = provider.source
      provider.onUpdate = { [weak self] nowPlaying in
        self?.receive(nowPlaying, from: source)
      }
      if let scriptable = provider as? ScriptablePlayerProvider {
        scriptable.onFailureChange = { [weak self] failure in
          self?.failures[source] = failure
        }
      }
      provider.start()
    }
  }

  /// Adds a provider later, e.g. the browser provider once the local server runs.
  func add(_ provider: any MediaProvider) {
    providers.append(provider)
    let source = provider.source
    provider.onUpdate = { [weak self] nowPlaying in
      self?.receive(nowPlaying, from: source)
    }
    provider.start()
  }

  func send(_ command: MediaCommand) async {
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
    selection.update(disabledSources.contains(source) ? nil : nowPlaying, for: source, at: Date())
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
