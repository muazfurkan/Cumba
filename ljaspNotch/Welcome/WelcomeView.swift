import SwiftUI

struct WelcomeView: View {
  @Bindable var settings: AppSettings
  let isInApplications: Bool
  let openSettings: @MainActor () -> Void
  let close: @MainActor () -> Void

  var body: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 96, height: 96)
          .accessibilityHidden(true)
        Text("Welcome to ljaspNotch")
          .font(.title.weight(.semibold))
        Text("Your notch is now a panel. Here's how to use it.")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)

      VStack(alignment: .leading, spacing: 16) {
        Tip(
          symbol: "cursorarrow.motionlines", title: "Rest the pointer on the notch",
          detail:
            "The panel opens; move away and it closes. Delays and a click-only mode are in Settings."
        )
        Tip(
          symbol: "menubar.rectangle", title: "Settings are in the menu bar",
          detail:
            "If the icon hides behind the notch, open ljaspNotch again from Finder or Spotlight.")
        Tip(
          symbol: "music.note.list", title: "Connect your apps",
          detail:
            "Spotify and Music work right away. YouTube needs the Chrome extension and Claude Code needs its hooks; Settings walks you through both."
        )
      }

      if !isInApplications {
        Label {
          Text(
            "Move ljaspNotch to your Applications folder: quit it, drag it there in Finder and open it again. Otherwise macOS may forget its permissions and the Chrome extension folder can move."
          )
          .fixedSize(horizontal: false, vertical: true)
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.yellow)
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12), in: .rect(cornerRadius: 10))
      }

      VStack(spacing: 16) {
        HStack {
          Text("Launch at login")
          Spacer()
          Toggle("Launch at login", isOn: .launchAtLogin(settings))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        HStack {
          Button("Open Settings") { openSettings() }
          Spacer()
          Button("Get Started") { close() }
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
      }

      Text("Free and open source. No telemetry.")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 32)
    .padding(.top, 36)
    .padding(.bottom, 24)
    .frame(width: 460)
  }
}

private struct Tip: View {
  let symbol: String
  let title: LocalizedStringKey
  let detail: LocalizedStringKey

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(.tint)
        .frame(width: 32)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(detail)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
