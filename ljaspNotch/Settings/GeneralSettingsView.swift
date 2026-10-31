import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
  let settings: AppSettings

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
      Section {
        LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
      }
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 240)
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
