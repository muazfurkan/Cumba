import AppKit
import SwiftUI

struct MediaWidgetView: View {
  let widget: MediaWidget
  @State private var glow: Color?
  @Environment(\.showsDetailedWidget) private var isDetailed

  private var media: MediaCoordinator { widget.media }

  var body: some View {
    WidgetCard(tint: glow) {
      if let nowPlaying = media.current, isDetailed {
        detailed(nowPlaying)
      } else if let nowPlaying = media.current {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            ArtworkView(nowPlaying: nowPlaying, size: 48, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 1) {
              Text(nowPlaying.title)
                .panelFont(.callout, weight: .semibold)
                .lineLimit(1)
              Text(nowPlaying.artist ?? nowPlaying.sourceName)
                .panelFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            sourceMenu(current: nowPlaying.source)
          }
          ProgressBar(nowPlaying: nowPlaying) { position in
            Task { await media.send(.seek(position)) }
          }
          controls(isPlaying: nowPlaying.isPlaying)
          if let failure = media.failures[nowPlaying.source] {
            FailureNote(failure: failure, source: nowPlaying.source) { widget.showSettings() }
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          WidgetHeader("Media", symbol: "music.note", color: .pink)
          Text("Nothing is playing.")
            .panelFont(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .task(id: glowKey) {
      guard let nowPlaying = media.current else {
        glow = nil
        return
      }
      glow = await ArtworkCache.shared.load(for: nowPlaying)?.color
    }
  }

  /// Alone in its tab: large artwork with the title, progress and controls beside it.
  private func detailed(_ nowPlaying: NowPlaying) -> some View {
    HStack(spacing: 16) {
      ArtworkView(nowPlaying: nowPlaying, size: 112, cornerRadius: 14)
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(nowPlaying.title)
              .panelFont(.title3, weight: .semibold)
              .lineLimit(2)
            Text([nowPlaying.artist, nowPlaying.album].compactMap { $0 }.joined(separator: " — "))
              .panelFont(.callout)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          sourceMenu(current: nowPlaying.source)
        }
        Spacer(minLength: 2)
        ProgressBar(nowPlaying: nowPlaying) { position in
          Task { await media.send(.seek(position)) }
        }
        controls(isPlaying: nowPlaying.isPlaying)
        if let failure = media.failures[nowPlaying.source] {
          FailureNote(failure: failure, source: nowPlaying.source) { widget.showSettings() }
        }
      }
    }
  }

  private var glowKey: String? {
    media.current.flatMap { ArtworkCache.key(for: $0) }
  }

  private func controls(isPlaying: Bool) -> some View {
    HStack(spacing: 18) {
      control("backward.fill", label: Text("Previous")) { await media.send(.previous) }
      control(
        isPlaying ? "pause.fill" : "play.fill",
        label: isPlaying ? Text("Pause") : Text("Play")
      ) { await media.send(.togglePlayPause) }
      control("forward.fill", label: Text("Next")) { await media.send(.next) }
    }
    .frame(maxWidth: .infinity)
  }

  private func control(
    _ symbol: String, label: Text, action: @escaping @MainActor () async -> Void
  ) -> some View {
    Button {
      Task { await action() }
    } label: {
      Image(systemName: symbol)
        .panelFont(.body)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(PanelButtonStyle(size: 30))
    .accessibilityLabel(label)
    .help(label)
  }

  @ViewBuilder private func sourceMenu(current: NowPlaying.Source) -> some View {
    if media.availableSources.count > 1 {
      Menu {
        ForEach(media.availableSources, id: \.self) { source in
          Button(source.displayName) { media.pin(source) }
        }
      } label: {
        Image(systemName: current.symbol)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel(Text("Switch Player"))
    }
  }
}

/// Thin progress bar; click to seek. Redraws once a second, and only while on screen.
private struct ProgressBar: View {
  let nowPlaying: NowPlaying
  let seek: (TimeInterval) -> Void

  var body: some View {
    if let duration = nowPlaying.duration, duration > 0 {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let position = nowPlaying.currentPosition(at: context.date) ?? 0
        VStack(spacing: 2) {
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.2))
              Capsule()
                .fill(.tint)
                .frame(width: proxy.size.width * min(1, position / duration))
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
              seek(duration * min(1, max(0, location.x / proxy.size.width)))
            }
          }
          .frame(height: 4)
          HStack {
            Text(Duration.seconds(position), format: .time(pattern: .minuteSecond))
            Spacer()
            Text(Duration.seconds(duration), format: .time(pattern: .minuteSecond))
          }
          .panelFont(size: 9, monospacedDigit: true)
          .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement()
      .accessibilityLabel(Text("Playback position"))
      .accessibilityValue(
        Text(
          Duration.seconds(nowPlaying.currentPosition() ?? 0), format: .time(pattern: .minuteSecond)
        ))
    }
  }
}

private struct FailureNote: View {
  let failure: AppleScriptRunner.Failure
  let source: NowPlaying.Source
  let openSettings: () -> Void

  var body: some View {
    switch failure {
    case .denied:
      Text(
        "Cumba may not control \(source.displayName). Allow it in System Settings > Privacy & Security > Automation."
      )
      .panelFont(.caption2)
      .foregroundStyle(.orange)
      .fixedSize(horizontal: false, vertical: true)
    case .needsPermission:
      Button("Allow control in Settings", action: openSettings)
        .panelFont(.caption2)
        .buttonStyle(.link)
    case .notRunning, .scriptError:
      EmptyView()
    }
  }
}
