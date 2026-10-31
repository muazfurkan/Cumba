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

  let size = WidgetSize.regular
  let media: MediaCoordinator

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private let openSettings: @MainActor () -> Void
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
    AnyView(MediaPermissionsView())
  }

  func shutdown() {
    isRunning = false
    liveActivities.dismiss(Self.activityID)
  }

  func showSettings() {
    openSettings()
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
        leading: AnyView(ArtworkView(nowPlaying: nowPlaying, size: 20, cornerRadius: 5)),
        trailing: AnyView(
          Image(systemName: "waveform")
            .symbolEffect(.variableColor.iterative, options: .repeating)
            .accessibilityLabel(Text("Playing")))))
  }
}

/// Album art from data (Music) or a URL (Spotify, YouTube), with a placeholder.
struct ArtworkView: View {
  let nowPlaying: NowPlaying
  let size: CGFloat
  var cornerRadius: CGFloat = 8

  var body: some View {
    Group {
      if let data = nowPlaying.artworkData, let image = NSImage(data: data) {
        Image(nsImage: image).resizable().scaledToFill()
      } else if let url = nowPlaying.artworkURL {
        AsyncImage(url: url) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          placeholder
        }
      } else {
        placeholder
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .accessibilityHidden(true)
  }

  private var placeholder: some View {
    Image(systemName: nowPlaying.source.symbol)
      .font(.system(size: size * 0.45))
      .frame(width: size, height: size)
      .background(.white.opacity(0.12))
  }
}
