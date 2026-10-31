import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var settings: AppSettings

  var body: some View {
    Form {
      Section {
        Toggle("Launch at login", isOn: launchAtLogin)
        if settings.launchAtLogin == .requiresApproval {
          VStack(alignment: .leading, spacing: 8) {
            Text("ljaspNotch needs your approval in System Settings to launch at login.")
              .foregroundStyle(.secondary)
            Button("Open Login Items Settings") {
              SMAppService.openSystemSettingsLoginItems()
            }
          }
        }
      }

      Section("Panel") {
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
      }

      Section {
        LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 430)
  }

  private var launchAtLogin: Binding<Bool> {
    Binding(
      get: { [settings] in
        settings.launchAtLogin == .enabled || settings.launchAtLogin == .requiresApproval
      },
      set: { [settings] enabled in
        Task { await settings.setLaunchAtLogin(enabled) }
      })
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
