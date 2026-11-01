import AVFoundation
import AppKit
import EventKit
import SwiftUI

/// Every permission Cumba can use, with its live state and one way to change it.
/// Nothing is asked at launch; each prompt starts from here or from the feature's settings.
struct PermissionsSettingsView: View {
  let info: SettingsPageInfo
  @State private var calendar = EKEventStore.authorizationStatus(for: .event)
  @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
  @State private var accessibility = MediaKeyTap.isTrusted
  @State private var location = LocationProvider()
  @State private var locationAccess = LocationProvider.Access.notAsked

  var body: some View {
    SettingsForm(info: info) {
      Section {
        Text(
          "Cumba asks for a permission only when you use the feature that needs it. Everything here can be changed again in System Settings."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      Section("Automation") {
        MediaPermissionsView()
      }
      Section {
        LabeledContent {
          calendarControl
        } label: {
          Label("Calendar", systemImage: "calendar")
          Text("Calendar widget: today's and tomorrow's events")
        }
        LabeledContent {
          locationControl
        } label: {
          Label("Location", systemImage: "location")
          Text("Weather widget: the weather where you are, rounded to about 10 km")
        }
        LabeledContent {
          cameraControl
        } label: {
          Label("Camera", systemImage: "camera")
          Text("Mirror widget, only while the panel shows it")
        }
        LabeledContent {
          if accessibility {
            PermissionGranted()
          } else {
            OpenPrivacySettings(pane: "Privacy_Accessibility")
          }
        } label: {
          Label("Accessibility", systemImage: "accessibility")
          Text("Optional: volume keys, when the notch replaces the system volume indicator")
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in
      refresh()
    }
    .onAppear(perform: refresh)
  }

  @ViewBuilder private var calendarControl: some View {
    switch calendar {
    case .fullAccess:
      PermissionGranted()
    case .notDetermined:
      Button("Allow…") {
        Task {
          NSApp.activate()
          _ = try? await EKEventStore().requestFullAccessToEvents()
          refresh()
        }
      }
    default:
      OpenPrivacySettings(pane: "Privacy_Calendars")
    }
  }

  @ViewBuilder private var locationControl: some View {
    switch locationAccess {
    case .allowed:
      PermissionGranted()
    case .notAsked:
      Button("Allow…") {
        Task {
          NSApp.activate()
          locationAccess = await location.requestAccess()
        }
      }
    case .denied:
      OpenPrivacySettings(pane: "Privacy_LocationServices")
    }
  }

  @ViewBuilder private var cameraControl: some View {
    switch camera {
    case .authorized:
      PermissionGranted()
    case .notDetermined:
      Button("Allow…") {
        Task {
          NSApp.activate()
          _ = await AVCaptureDevice.requestAccess(for: .video)
          refresh()
        }
      }
    default:
      OpenPrivacySettings(pane: "Privacy_Camera")
    }
  }

  private func refresh() {
    calendar = EKEventStore.authorizationStatus(for: .event)
    camera = AVCaptureDevice.authorizationStatus(for: .video)
    accessibility = MediaKeyTap.isTrusted
    locationAccess = location.access
  }
}

struct PermissionGranted: View {
  var body: some View {
    Label("Allowed", systemImage: "checkmark.circle.fill")
      .foregroundStyle(.green)
  }
}

/// Opens a pane of System Settings > Privacy & Security.
struct OpenPrivacySettings: View {
  let pane: String

  var body: some View {
    Button("Open System Settings") {
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
        NSWorkspace.shared.open(url)
      }
    }
  }
}
