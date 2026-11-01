import AppKit
import SwiftUI

/// The system indicators, each on only while its setting is: volume and brightness changes
/// in the notch (optionally handling those keys instead of macOS), a low battery, and a dot
/// while a microphone or camera is in use.
@MainActor
final class SystemIndicators {
  private let settings: AppSettings
  private let liveActivities: LiveActivityCenter
  private let volume = VolumeMonitor()
  private let brightness = BrightnessMonitor()
  private let keyTap: MediaKeyTap
  private let privacy = PrivacyIndicatorMonitor()
  private let battery = BatteryMonitor()
  private var lastLevel: VolumeMonitor.Level?
  private var isKeyTapRunning = false
  private var activeObserver: NSObjectProtocol?

  private static let volumeActivityID = "volume"
  private static let brightnessActivityID = "brightness"
  private static let privacyActivityID = "privacy"
  private static let lowBatteryActivityID = "lowBattery"

  init(settings: AppSettings, liveActivities: LiveActivityCenter) {
    self.settings = settings
    self.liveActivities = liveActivities
    keyTap = MediaKeyTap(volume: volume, brightness: brightness)
    keyTap.onBrightnessChange = { [weak self] level in self?.brightnessChanged(level) }
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
      _ = settings.showsBrightnessChanges
      _ = settings.replacesBrightnessIndicator
      _ = settings.showsPrivacyIndicators
      _ = settings.showsLowBattery
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
    if settings.showsBrightnessChanges {
      brightness.onChange = { [weak self] level in self?.brightnessChanged(level) }
      brightness.start()
    } else {
      brightness.stop()
      brightness.onChange = nil
      liveActivities.dismiss(Self.brightnessActivityID)
    }
    keyTap.handlesVolume = settings.showsVolumeChanges && settings.replacesVolumeIndicator
    keyTap.handlesBrightness =
      settings.showsBrightnessChanges && settings.replacesBrightnessIndicator
    let wantsKeyTap = keyTap.handlesVolume || keyTap.handlesBrightness
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
    if settings.showsLowBattery {
      battery.onChange = { [weak self] status in self?.batteryChanged(status) }
      battery.start()
    } else {
      battery.stop()
      battery.onChange = nil
      liveActivities.dismiss(Self.lowBatteryActivityID)
    }
  }

  private func volumeChanged(_ level: VolumeMonitor.Level) {
    guard level != lastLevel else { return }
    lastLevel = level
    let shown = level.isMuted ? 0 : level.volume
    liveActivities.show(
      LiveActivity(
        id: Self.volumeActivityID, priority: .volume,
        leading: AnyView(LevelSymbol(name: Self.speakerSymbol(shown), label: Text("Volume"))),
        trailing: AnyView(LevelBar(level: shown, label: Text("Volume")))),
      for: .seconds(1.5))
  }

  private func brightnessChanged(_ level: Float) {
    liveActivities.show(
      LiveActivity(
        id: Self.brightnessActivityID, priority: .volume,
        leading: AnyView(
          LevelSymbol(
            name: level < 0.5 ? "sun.min.fill" : "sun.max.fill", label: Text("Brightness"))
        ),
        trailing: AnyView(LevelBar(level: level, label: Text("Brightness")))),
      for: .seconds(1.5))
  }

  /// A low battery stays beside the notch until the charger is plugged in.
  private func batteryChanged(_ status: BatteryWidget.Status?) {
    guard let status, status.isLow else {
      liveActivities.dismiss(Self.lowBatteryActivityID)
      return
    }
    liveActivities.show(
      LiveActivity(
        id: Self.lowBatteryActivityID, priority: .lowBattery,
        leading: AnyView(LowBatteryRing(percent: status.percent)),
        trailing: AnyView(LowBatteryPercent(percent: status.percent))))
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
