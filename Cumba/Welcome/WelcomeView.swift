import SwiftUI

struct WelcomeView: View {
  @Bindable var settings: AppSettings
  let isInApplications: Bool
  let openSettings: @MainActor () -> Void
  let close: @MainActor () -> Void
  @State private var hasOpenedPanel = false

  var body: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 96, height: 96)
          .accessibilityHidden(true)
        Text("Welcome to Cumba")
          .font(.title.weight(.semibold))
        Text("Your notch is now a panel. Here's how to use it.")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)

      TryItCard(hasOpened: hasOpenedPanel)

      VStack(alignment: .leading, spacing: 16) {
        Tip(
          symbol: "contextualmenu.and.cursorarrow", title: "Right-click the notch",
          detail:
            "Settings, Reset Panel and Quit are always there, even when the menu bar icon is hidden."
        )
        Tip(
          symbol: "square.grid.2x2", title: "Make it yours",
          detail:
            "Add, remove and reorder widgets in Settings > Widgets, and connect Spotify, YouTube or Claude Code."
        )
      }

      if !isInApplications {
        Label {
          Text(
            "Move Cumba to your Applications folder: quit it, drag it there in Finder and open it again. Otherwise macOS may forget its permissions and the Chrome extension folder can move."
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
    .onReceive(NotificationCenter.default.publisher(for: .notchPanelDidOpen)) { _ in
      withAnimation(.smooth) { hasOpenedPanel = true }
    }
  }
}

/// The first step, done live: it checks itself off when the panel opens.
private struct TryItCard: View {
  let hasOpened: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: hasOpened ? "checkmark.circle.fill" : "cursorarrow.motionlines")
        .font(.title)
        .foregroundStyle(hasOpened ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 36)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(hasOpened ? "That's the panel" : "Try it: rest the pointer on the notch")
          .font(.headline)
        Text(
          hasOpened
            ? "It closes when you move away. Change the delay or switch to click-only in Settings."
            : "The panel opens after a short moment."
        )
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(.tint.opacity(hasOpened ? 0 : 0.08), in: .rect(cornerRadius: 12))
    .background(.green.opacity(hasOpened ? 0.12 : 0), in: .rect(cornerRadius: 12))
    .accessibilityElement(children: .combine)
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
