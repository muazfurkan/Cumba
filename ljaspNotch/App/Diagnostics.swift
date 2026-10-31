import AVFoundation
import AppKit
import EventKit

/// Text for bug reports (SPEC § 14): versions, Mac model, screens, permission states and
/// enabled widgets. Never includes tokens, file paths, Claude Code content or other
/// personal data.
@MainActor
enum Diagnostics {
  struct Sources {
    let settings: AppSettings
    let themes: ThemeStore
    let layout: LayoutStore
    let server: LocalServer
  }

  static func report(_ sources: Sources) async -> String {
    let spotify = await AppleScriptRunner.shared.permission(
      for: SpotifyAdapter().bundleID, ask: false)
    let music = await AppleScriptRunner.shared.permission(for: MusicAdapter().bundleID, ask: false)
    let port = sources.settings.serverPort
    let token = sources.server.token
    let hooks = await Task.detached {
      (try? HookInstaller.standard.status(port: port, token: token)).map { "\($0)" } ?? "unreadable"
    }.value

    var lines: [String] = []
    lines.append("ljaspNotch \(AppInfo.version) (\(AppInfo.build))")
    lines.append("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
    lines.append("Model: \(macModel())")
    for (index, screen) in NSScreen.screens.enumerated() {
      let size = screen.frame.size
      var line =
        "Screen \(index + 1): \(Int(size.width))×\(Int(size.height)) @\(Int(screen.backingScaleFactor))x"
      if let notch = screen.notchGeometry()?.notchRect {
        line += ", notch \(Int(notch.width))×\(Int(notch.height))"
      }
      lines.append(line)
    }
    let settings = sources.settings
    lines.append(
      "Panel: paused=\(settings.isPaused) hover=\(settings.opensOnHover) open=\(settings.openDelay)s close=\(settings.closeDelay)s fullScreenHide=\(settings.hidesInFullScreen) virtualNotch=\(settings.usesVirtualNotch)"
    )
    let theme = sources.themes.current
    lines.append(
      "Theme: \(sources.themes.isBuiltIn(theme) ? theme.id : "custom") (\(theme.material.rawValue))"
    )
    for tab in sources.layout.layout.tabs {
      lines.append("Tab: \(tab.widgets.joined(separator: ", "))")
    }
    lines.append(
      "Server: \(describe(sources.server.status)), browsers=\(sources.server.browserHub.connectionCount)"
    )
    lines.append("Claude Code hooks: \(hooks)")
    lines.append(
      "Permissions: calendar=\(EKEventStore.authorizationStatus(for: .event).rawValue) camera=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue) spotify=\(spotify) music=\(music)"
    )
    return lines.joined(separator: "\n")
  }

  static func copy(_ sources: Sources) async {
    let text = await report(sources)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private static func describe(_ status: LocalServer.Status) -> String {
    switch status {
    case .running(let port): "running on \(port)"
    case .stopped: "stopped"
    case .failed: "failed"
    }
  }

  private static func macModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    guard size > 0 else { return "unknown" }
    var buffer = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buffer, &size, nil, 0)
    return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
  }
}
