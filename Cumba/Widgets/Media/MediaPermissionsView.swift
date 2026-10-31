import AppKit
import SwiftUI

/// Settings > Widgets > Media: shows and requests Automation access per player. The
/// system prompt only appears from here, never from the panel.
struct MediaPermissionsView: View {
  private struct Player: Identifiable {
    let source: NowPlaying.Source
    let bundleID: String
    var id: String { bundleID }
  }

  private let players = [
    Player(source: .spotify, bundleID: SpotifyAdapter().bundleID),
    Player(source: .appleMusic, bundleID: MusicAdapter().bundleID),
  ]

  @State private var permissions: [String: AppleScriptRunner.Permission] = [:]
  @State private var running: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(
        "To show artwork and use the controls, Cumba needs Automation access to each player. Open the player, then allow it here."
      )
      .panelFont(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      ForEach(players) { player in
        HStack {
          Label(player.source.displayName, systemImage: player.source.symbol)
          Spacer()
          status(for: player)
        }
      }
    }
    .task { await refresh() }
  }

  @ViewBuilder private func status(for player: Player) -> some View {
    switch permissions[player.bundleID] {
    case .granted:
      Label("Allowed", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .denied:
      Button("Open Automation Settings") {
        if let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        {
          NSWorkspace.shared.open(url)
        }
      }
    case .notDetermined, nil:
      if running.contains(player.bundleID) {
        Button("Allow") {
          Task {
            NSApp.activate()
            permissions[player.bundleID] = await AppleScriptRunner.shared.permission(
              for: player.bundleID, ask: true)
          }
        }
      } else {
        Text("Not running")
          .foregroundStyle(.secondary)
      }
    }
  }

  private func refresh() async {
    for player in players {
      if AppleScriptRunner.isRunning(player.bundleID) {
        running.insert(player.bundleID)
      }
      permissions[player.bundleID] = await AppleScriptRunner.shared.permission(
        for: player.bundleID, ask: false)
    }
  }
}
