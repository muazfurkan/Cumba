import AppKit
import SwiftUI

/// The optional system indicators, each on only while its setting is: volume changes in
/// the notch (optionally handling the volume keys instead of macOS), and a dot while a
/// microphone or camera is in use.
@MainActor
final class SystemIndicators {
  private let settings: AppSettings
  private let liveActivities: LiveActivityCenter
  private let volume = VolumeMonitor()
  private let keyTap: VolumeKeyTap
  private let privacy = PrivacyIndicatorMonitor()
  private var lastLevel: VolumeMonitor.Level?
  private var isKeyTapRunning = false
  private var activeObserver: NSObjectProtocol?

  private static let volumeActivityID = "volume"
  private static let privacyActivityID = "privacy"

  init(settings: AppSettings, liveActivities: LiveActivityCenter) {
    self.settings = settings
    self.liveActivities = liveActivities
    keyTap = VolumeKeyTap(volume: volume)
  }

  func start() {
    // Accessibility may be granted while the app runs; try the key tap again then.
    activeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.apply() }
    }
    apply()
    observeSettings()
  }

  private func observeSettings() {
    withObservationTracking {
      _ = settings.showsVolumeChanges
      _ = settings.replacesVolumeIndicator
      _ = settings.showsPrivacyIndicators
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.apply()
        self?.observeSettings()
      }
    }
  }

  private func apply() {
    if settings.showsVolumeChanges {
      volume.onChange = { [weak self] level in self?.volumeChanged(level) }
      volume.start()
      if lastLevel == nil {
        lastLevel = volume.level
      }
    } else {
      volume.stop()
      volume.onChange = nil
      lastLevel = nil
      liveActivities.dismiss(Self.volumeActivityID)
    }
    let wantsKeyTap = settings.showsVolumeChanges && settings.replacesVolumeIndicator
    if wantsKeyTap && !isKeyTapRunning {
      isKeyTapRunning = keyTap.start()
    } else if !wantsKeyTap && isKeyTapRunning {
      keyTap.stop()
      isKeyTapRunning = false
    }
    if settings.showsPrivacyIndicators {
      privacy.onChange = { [weak self] state in self?.privacyChanged(state) }
      privacy.start()
      privacyChanged(privacy.state)
    } else {
      privacy.stop()
      privacy.onChange = nil
      liveActivities.dismiss(Self.privacyActivityID)
    }
  }

  private func volumeChanged(_ level: VolumeMonitor.Level) {
    guard level != lastLevel else { return }
    lastLevel = level
    let shown = level.isMuted ? 0 : level.volume
    liveActivities.show(
      LiveActivity(
        id: Self.volumeActivityID, priority: .volume,
        leading: AnyView(
          Image(systemName: Self.speakerSymbol(shown))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(Text("Volume"))),
        trailing: AnyView(VolumeBar(level: shown))),
      for: .seconds(1.5))
  }

  private func privacyChanged(_ state: PrivacyIndicatorMonitor.State) {
    guard state.microphone || state.camera else {
      liveActivities.dismiss(Self.privacyActivityID)
      return
    }
    liveActivities.show(
      LiveActivity(
        id: Self.privacyActivityID, priority: .privacy,
        leading: AnyView(
          HStack(spacing: 3) {
            if state.camera {
              Circle().fill(.green).frame(width: 7, height: 7)
            }
            if state.microphone {
              Circle().fill(.orange).frame(width: 7, height: 7)
            }
          }),
        trailing: AnyView(
          HStack(spacing: 4) {
            if state.camera {
              Image(systemName: "video.fill").foregroundStyle(.green)
                .accessibilityLabel(Text("Camera in use"))
            }
            if state.microphone {
              Image(systemName: "mic.fill").foregroundStyle(.orange)
                .accessibilityLabel(Text("Microphone in use"))
            }
          }
          .font(.caption))))
  }

  static func speakerSymbol(_ volume: Float) -> String {
    switch volume {
    case ...0: "speaker.slash.fill"
    case ..<0.34: "speaker.wave.1.fill"
    case ..<0.67: "speaker.wave.2.fill"
    default: "speaker.wave.3.fill"
    }
  }
}

/// The volume level as a short bar beside the notch.
private struct VolumeBar: View {
  let level: Float

  var body: some View {
    Capsule()
      .fill(.white.opacity(0.25))
      .frame(width: 44, height: 5)
      .overlay(alignment: .leading) {
        Capsule()
          .fill(.white)
          .frame(width: 44 * CGFloat(min(max(level, 0), 1)), height: 5)
      }
      .animation(.easeOut(duration: 0.12), value: level)
      .accessibilityValue(Text(Double(level), format: .percent.precision(.fractionLength(0))))
  }
}
