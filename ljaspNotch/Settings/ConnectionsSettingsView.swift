import AppKit
import SwiftUI

/// Local server status, port and token, and how to install the Chrome extension.
struct ConnectionsSettingsView: View {
  let server: LocalServer
  @Bindable var settings: AppSettings
  @State private var portText = ""
  @State private var showsToken = false

  var body: some View {
    Form {
      Section("Local Server") {
        LabeledContent("Status") { status }
        LabeledContent("Port") {
          HStack {
            TextField("Port", text: $portText)
              .labelsHidden()
              .frame(width: 80)
              .onSubmit(applyPort)
            Button("Apply", action: applyPort)
              .disabled(UInt16(portText) == nil || UInt16(portText) == settings.serverPort)
          }
        }
        LabeledContent("Token") {
          HStack {
            Text(showsToken ? server.token : String(repeating: "•", count: 12))
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .lineLimit(1)
              .truncationMode(.middle)
            Button(showsToken ? "Hide" : "Show") { showsToken.toggle() }
            Button("Copy") { copyToken() }
            Button("Regenerate") {
              Task { await server.regenerateToken(port: settings.serverPort) }
            }
          }
        }
        Text(
          "The server only listens on this Mac (127.0.0.1) and accepts only requests that carry this token. After regenerating it, paste the new token into the Chrome extension and reinstall the Claude Code hooks."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      Section("Chrome Extension") {
        Text(
          "1. Open chrome://extensions and turn on Developer mode.\n2. Click “Load unpacked” and choose the extension folder.\n3. Open the extension's options and paste the port and the token."
        )
        .fixedSize(horizontal: false, vertical: true)
        Button("Show Extension Folder") {
          if let url = Bundle.main.url(forResource: "chrome", withExtension: nil) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
          }
        }
        LabeledContent("Connected browsers", value: "\(server.browserHub.connectionCount)")
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 520)
    .onAppear { portText = String(settings.serverPort) }
  }

  @ViewBuilder private var status: some View {
    switch server.status {
    case .running(let port):
      Label("Running on port \(String(port))", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .stopped:
      Text("Stopped")
        .foregroundStyle(.secondary)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
  }

  /// Copies the token marked as concealed, so clipboard managers and Universal Clipboard
  /// skip it, and clears it again after a minute if nothing else was copied since.
  private func copyToken() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(server.token, forType: .string)
    pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    let changeCount = pasteboard.changeCount
    Task {
      try? await Task.sleep(for: .seconds(60))
      if NSPasteboard.general.changeCount == changeCount {
        NSPasteboard.general.clearContents()
      }
    }
  }

  private func applyPort() {
    guard let port = UInt16(portText), port >= 1024 else { return }
    settings.serverPort = port
    Task { await server.start(port: port) }
  }
}
