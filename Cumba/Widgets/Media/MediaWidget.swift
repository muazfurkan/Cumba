import AppKit
import Observation
import SwiftUI

/// Mini player for whatever the `MediaCoordinator` picks. While something plays, the
/// closed notch shows its artwork and a waveform as a live activity.
@MainActor
@Observable
final class MediaWidget: NotchWidget {
  static let kind = "media"
  static var title: String { String(localized: "Media", comment: "Widget name") }
  static let symbol = "music.note"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "Spotify, Music and YouTube with artwork and controls",
      comment: "Widget description")
  }
  static let addedByDefault = true

  let media: MediaCoordinator

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private let openSettings: @MainActor (SettingsWindowController.Tab) -> Void
  @ObservationIgnored private var isRunning = true

  private static let activityID = "media"

  required init(context: WidgetContext) {
    media = context.media
    liveActivities = context.liveActivities
    openSettings = context.openSettings
    observeNowPlaying()
  }

  func makeView() -> AnyView {
    AnyView(MediaWidgetView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(MediaSettingsView(media: media))
  }

  func shutdown() {
    isRunning = false
    liveActivities.dismiss(Self.activityID)
  }

  func showSettings() {
    openSettings(.permissions)
  }

  private func observeNowPlaying() {
    guard isRunning else { return }
    withObservationTracking {
      updateLiveActivity(media.current)
    } onChange: { [weak self] in
      Task { @MainActor in self?.observeNowPlaying() }
    }
  }

  private func updateLiveActivity(_ nowPlaying: NowPlaying?) {
    guard let nowPlaying, nowPlaying.isPlaying else {
      liveActivities.dismiss(Self.activityID)
      return
    }
    liveActivities.show(
      LiveActivity(
        id: Self.activityID, priority: .media,
        leading: AnyView(PeekArtwork(nowPlaying: nowPlaying)),
        trailing: AnyView(PeekWaveform())))
  }
}

/// The artwork beside the closed notch, as tall as the notch allows.
private struct PeekArtwork: View {
  let nowPlaying: NowPlaying
  @Environment(\.peekHeight) private var height

  var body: some View {
    ArtworkView(nowPlaying: nowPlaying, size: max(18, height - 10), cornerRadius: 6)
  }
}

/// A playing waveform beside the closed notch, sized to it.
private struct PeekWaveform: View {
  @Environment(\.peekHeight) private var height

  var body: some View {
    Image(systemName: "waveform")
      .font(.system(size: max(13, height * 0.5), weight: .semibold))
      .symbolEffect(.variableColor.iterative, options: .repeating)
      .accessibilityLabel(Text("Playing"))
  }
}

/// Album art from data (Music) or a URL (Spotify, YouTube), decoded once per track by
/// `ArtworkCache`, with a placeholder.
struct ArtworkView: View {
  let nowPlaying: NowPlaying
  let size: CGFloat
  var cornerRadius: CGFloat = 8
  @State private var entry: ArtworkCache.Entry?

  var body: some View {
    Group {
      if let image = entry?.image {
        Image(nsImage: image).resizable().scaledToFill()
          .transition(.opacity)
      } else {
        placeholder
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: .black.opacity(size > 30 ? 0.35 : 0), radius: 6, y: 3)
    .accessibilityHidden(true)
    .task(id: ArtworkCache.key(for: nowPlaying)) {
      entry = ArtworkCache.shared.cached(for: nowPlaying)
      let loaded = await ArtworkCache.shared.load(for: nowPlaying)
      withAnimation(.easeOut(duration: 0.2)) { entry = loaded }
    }
  }

  private var placeholder: some View {
    Image(systemName: nowPlaying.source.symbol)
      .font(.system(size: size * 0.45))
      .frame(width: size, height: size)
      .background(.white.opacity(0.12))
  }
}

/// Settings > Widgets > Media: where media comes from, which players to show, and
/// Automation access when AppleScript is used.
private struct MediaSettingsView: View {
  @Bindable var media: MediaCoordinator

  var body: some View {
    Toggle("Read media from every app", isOn: $media.usesSystemNowPlaying)
    Group {
      if media.usesSystemNowPlaying && media.systemNowPlayingFailed {
        Text(
          "The system's Now Playing can't be read on this Mac, so Cumba uses Spotify, Music and the YouTube extension."
        )
      } else if media.usesSystemNowPlaying {
        Text(
          "Shows what any app plays, like Control Center: Safari, Chrome, YouTube, Spotify, Music, podcasts and more, with no extension or Automation access. A small helper reads it through macOS's own perl."
        )
      } else {
        Text("Only Spotify and Music, through AppleScript, and YouTube through the extension.")
      }
    }
    .panelFont(.caption)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    ForEach(sources, id: \.self) { source in
      Toggle(isOn: enabled(source)) {
        Label(source.displayName, systemImage: source.symbol)
      }
    }
    if !media.isUsingSystemNowPlaying {
      MediaPermissionsView()
    }
  }

  /// Browsers and other apps come only from the system's Now Playing.
  private var sources: [NowPlaying.Source] {
    NowPlaying.Source.allCases.filter {
      media.isUsingSystemNowPlaying || ($0 != .browser && $0 != .otherApp)
    }
  }

  private func enabled(_ source: NowPlaying.Source) -> Binding<Bool> {
    Binding(
      get: { [media] in !media.disabledSources.contains(source) },
      set: { [media] isOn in
        if isOn {
          media.disabledSources.remove(source)
        } else {
          media.disabledSources.insert(source)
        }
      })
  }
}
