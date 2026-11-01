import SwiftUI

/// The display the panel is on, and what happens in full screen and without a notch.
struct DisplaysSettingsView: View {
  let info: SettingsPageInfo
  @Bindable var settings: AppSettings

  var body: some View {
    SettingsForm(info: info) {
      Section("Show the Panel On") {
        Picker(selection: $settings.panelScreen) {
          Text("The display with a notch").tag(AppSettings.PanelScreen.notched)
          Text("The main display").tag(AppSettings.PanelScreen.main)
          Text("The display with the pointer").tag(AppSettings.PanelScreen.pointer)
        } label: {
          InfoLabel(
            "Display",
            help: "Displays without a notch get a notch drawn in the middle of the menu bar.")
        }
        Toggle(isOn: $settings.usesVirtualNotch) {
          InfoLabel(
            "Show a virtual notch when no screen has one",
            help:
              "With no notch at all, for example with the lid closed, the main display gets one.")
        }
      }
      Section("Full Screen") {
        Toggle(isOn: $settings.hidesInFullScreen) {
          InfoLabel(
            "Hide in full screen apps",
            help: "The notch steps aside while a video or an app fills the screen.")
        }
      }
    }
  }
}

/// How the panel opens and closes.
struct BehaviorSettingsView: View {
  let info: SettingsPageInfo
  @Bindable var settings: AppSettings

  var body: some View {
    SettingsForm(info: info) {
      Section("Opening") {
        Picker(selection: $settings.opensOnHover) {
          Text("On hover").tag(true)
          Text("On click").tag(false)
        } label: {
          InfoLabel(
            "Open the panel",
            help: "On hover, the panel opens once the pointer rests on the notch for a moment.")
        }
        .pickerStyle(.segmented)
        if settings.opensOnHover {
          DelaySlider(
            title: "Open delay", value: $settings.openDelay, range: AppSettings.openDelayRange)
        }
        DelaySlider(
          title: "Close delay", value: $settings.closeDelay, range: AppSettings.closeDelayRange)
      }
      Section("Feedback") {
        Toggle(isOn: $settings.hapticFeedback) {
          InfoLabel(
            "Haptic feedback",
            help: "The trackpad taps lightly when the panel opens or tabs change.")
        }
      }
    }
  }
}

/// Volume, brightness, battery and the microphone or camera beside the notch.
struct IndicatorsSettingsView: View {
  let info: SettingsPageInfo
  @Bindable var settings: AppSettings
  @State private var isTrusted = MediaKeyTap.isTrusted

  var body: some View {
    SettingsForm(info: info) {
      Section("Volume and Brightness") {
        Toggle("Show volume changes in the notch", isOn: $settings.showsVolumeChanges)
        if settings.showsVolumeChanges {
          Toggle(isOn: replaces(\.replacesVolumeIndicator)) {
            InfoLabel(
              "Replace the system volume indicator",
              help: "Cumba handles the volume keys so only the notch shows the change.")
          }
        }
        Toggle("Show brightness changes in the notch", isOn: $settings.showsBrightnessChanges)
        if settings.showsBrightnessChanges {
          Toggle(isOn: replaces(\.replacesBrightnessIndicator)) {
            InfoLabel(
              "Replace the system brightness indicator",
              help: "Cumba handles the brightness keys so only the notch shows the change.")
          }
        }
        if replacesAny && !isTrusted {
          Text("Replacing needs Accessibility access.")
            .foregroundStyle(.secondary)
          OpenPrivacySettings(pane: "Privacy_Accessibility")
        }
      }
      Section("Battery and Privacy") {
        Toggle(isOn: $settings.showsLowBattery) {
          InfoLabel(
            "Show a low battery in the notch",
            help: "At 20% or less on battery, a red ring and the percentage stay beside the notch.")
        }
        Toggle(isOn: $settings.showsPrivacyIndicators) {
          InfoLabel(
            "Show when the microphone or camera is in use",
            help: "A dot beside the notch, like the one in the menu bar.")
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in
      isTrusted = MediaKeyTap.isTrusted
    }
  }

  private var replacesAny: Bool {
    (settings.showsVolumeChanges && settings.replacesVolumeIndicator)
      || (settings.showsBrightnessChanges && settings.replacesBrightnessIndicator)
  }

  /// Turning it on without Accessibility access shows the system prompt first.
  private func replaces(_ setting: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
    Binding(
      get: { settings[keyPath: setting] },
      set: { isOn in
        if isOn && !MediaKeyTap.isTrusted {
          MediaKeyTap.requestAccess()
        }
        settings[keyPath: setting] = isOn
        isTrusted = MediaKeyTap.isTrusted
      })
  }
}
