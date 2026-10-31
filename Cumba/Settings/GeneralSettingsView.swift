import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var settings: AppSettings
  let updates: UpdateChecker
  let diagnostics: Diagnostics.Sources
  @State private var copiedDiagnostics = false
  @State private var isTrusted = MediaKeyTap.isTrusted

  var body: some View {
    Form {
      Section {
        Toggle("Launch at login", isOn: .launchAtLogin(settings))
        if settings.launchAtLogin == .requiresApproval {
          VStack(alignment: .leading, spacing: 8) {
            Text("Cumba needs your approval in System Settings to launch at login.")
              .foregroundStyle(.secondary)
            Button("Open Login Items Settings") {
              SMAppService.openSystemSettingsLoginItems()
            }
          }
        }
      }

      Section("Panel") {
        Picker("Show on", selection: $settings.panelScreen) {
          Text("The display with a notch").tag(AppSettings.PanelScreen.notched)
          Text("The main display").tag(AppSettings.PanelScreen.main)
          Text("The display with the pointer").tag(AppSettings.PanelScreen.pointer)
        }
        Picker("Tabs", selection: $settings.tabBarPosition) {
          Text("At the bottom").tag(AppSettings.TabBarPosition.bottom)
          Text("At the top").tag(AppSettings.TabBarPosition.top)
        }
        Picker("Open the panel", selection: $settings.opensOnHover) {
          Text("When the pointer rests on the notch").tag(true)
          Text("Only on click").tag(false)
        }
        if settings.opensOnHover {
          DelaySlider(
            title: "Open delay", value: $settings.openDelay, range: AppSettings.openDelayRange)
        }
        DelaySlider(
          title: "Close delay", value: $settings.closeDelay, range: AppSettings.closeDelayRange)
        Toggle("Hide in full screen apps", isOn: $settings.hidesInFullScreen)
        Toggle("Show a virtual notch when no screen has one", isOn: $settings.usesVirtualNotch)
        Toggle("Haptic feedback when the panel opens", isOn: $settings.hapticFeedback)
      }

      Section("Indicators") {
        Toggle("Show volume changes in the notch", isOn: $settings.showsVolumeChanges)
        if settings.showsVolumeChanges {
          Toggle("Replace the system volume indicator", isOn: replaces(\.replacesVolumeIndicator))
        }
        Toggle("Show brightness changes in the notch", isOn: $settings.showsBrightnessChanges)
        if settings.showsBrightnessChanges {
          Toggle(
            "Replace the system brightness indicator",
            isOn: replaces(\.replacesBrightnessIndicator))
        }
        if settings.showsVolumeChanges || settings.showsBrightnessChanges {
          Text(
            "Replacing handles those keys so only the notch shows the change. It needs Accessibility access."
          )
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          if replacesAny && !isTrusted {
            OpenPrivacySettings(pane: "Privacy_Accessibility")
          }
        }
        Toggle(
          "Show when the microphone or camera is in use", isOn: $settings.showsPrivacyIndicators)
      }

      Section("Updates") {
        Toggle("Check for updates automatically", isOn: $settings.checksForUpdates)
        Toggle("Include pre-releases", isOn: $settings.includesPrereleases)
        HStack {
          Button("Check Now") {
            Task { await updates.checkNow() }
          }
          Spacer()
          updateStatus
        }
      }

      Section {
        LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
        LabeledContent("Resource use") { ResourceUsageLabel() }
        HStack {
          Button("Copy Diagnostics") {
            Task {
              await Diagnostics.copy(diagnostics)
              copiedDiagnostics = true
            }
          }
          if copiedDiagnostics {
            Text("Copied. It contains no personal data.")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 600)
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

  @ViewBuilder private var updateStatus: some View {
    if let release = updates.available {
      Link("Version \(release.version) is available", destination: release.url)
    } else if updates.lastCheckFailed {
      Text("Couldn't check for updates.")
        .foregroundStyle(.secondary)
    } else if updates.lastChecked != nil {
      Text("Cumba is up to date.")
        .foregroundStyle(.secondary)
    }
  }
}

extension Binding where Value == Bool {
  /// On while the login item is registered, including while it waits for approval.
  @MainActor static func launchAtLogin(_ settings: AppSettings) -> Binding<Bool> {
    Binding(
      get: { settings.launchAtLogin == .enabled || settings.launchAtLogin == .requiresApproval },
      set: { enabled in Task { await settings.setLaunchAtLogin(enabled) } })
  }
}

/// Slider for a delay in seconds with its value shown next to it.
struct DelaySlider: View {
  let title: LocalizedStringKey
  @Binding var value: Double
  let range: ClosedRange<Double>

  var body: some View {
    LabeledContent(title) {
      HStack {
        Slider(value: $value, in: range, step: 0.05)
        Text(
          Measurement(value: value, unit: UnitDuration.seconds),
          format: .measurement(
            width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(2)))
        )
        .monospacedDigit()
        .frame(width: 64, alignment: .trailing)
      }
    }
  }
}
