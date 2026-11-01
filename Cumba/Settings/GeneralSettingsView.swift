import ServiceManagement
import SwiftUI

/// Starting with the Mac, updates, and the app's version and resource use.
struct GeneralSettingsView: View {
  let info: SettingsPageInfo
  @Bindable var settings: AppSettings
  let updates: UpdateChecker
  let diagnostics: Diagnostics.Sources
  @State private var copiedDiagnostics = false

  var body: some View {
    SettingsForm(info: info) {
      Section("Startup") {
        Toggle(isOn: .launchAtLogin(settings)) {
          InfoLabel("Launch at login", help: "Cumba starts when you log in to your Mac.")
        }
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

      Section("Updates") {
        Toggle(isOn: $settings.checksForUpdates) {
          InfoLabel(
            "Check for updates automatically",
            help: "Once a day, Cumba asks GitHub for the latest release. Nothing else is sent.")
        }
        Toggle("Include pre-releases", isOn: $settings.includesPrereleases)
        HStack {
          updateStatus
          Spacer()
          Button("Check Now") {
            Task { await updates.checkNow() }
          }
        }
      }

      Section("About") {
        LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
        LabeledContent("Resource use") { ResourceUsageLabel() }
        LabeledContent {
          Button("Play") {
            NotificationCenter.default.post(name: .notchSayHello, object: nil)
          }
        } label: {
          InfoLabel(
            "Hello animation",
            help: "The notch writes hello, as it does the first time Cumba starts.")
        }
        HStack {
          if copiedDiagnostics {
            Text("Copied. It contains no personal data.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Copy Diagnostics") {
            Task {
              await Diagnostics.copy(diagnostics)
              copiedDiagnostics = true
            }
          }
        }
      }

      Section {
        LabeledContent {
          Button("Quit") { NSApp.terminate(nil) }
        } label: {
          Text("Quit Cumba")
        }
      }
    }
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
