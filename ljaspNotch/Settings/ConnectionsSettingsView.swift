import AppKit
import SwiftUI

/// The Chrome extension connection: on/off, how to install the extension, and the local
/// server's status, port and token. The server runs only while the connection is on.
struct ConnectionsSettingsView: View {
  let server: LocalServer
  @Bindable var settings: AppSettings
  @State private var portText = ""
  @State private var showsToken = false

  var body: some View {
    Form {
      Section("Chrome Extension") {
        Toggle("Connect the YouTube extension", isOn: extensionEnabled)
        Text(
          "Turn this on only if you use the extension. ljaspNotch then listens on this Mac (127.0.0.1) for the ljaspNotch extension; nothing is reachable from the network."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        if settings.browserExtensionEnabled {
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

      if settings.browserExtensionEnabled {
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
              Text(showsToken ? server.extensionToken : String(repeating: "•", count: 12))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
              Button(showsToken ? "Hide" : "Show") { showsToken.toggle() }
              Button("Copy") { SecretCopy.copy(server.extensionToken) }
              Button("Regenerate") {
                Task { await server.regenerateExtensionToken(port: settings.serverPort) }
              }
            }
          }
          Text(
            "Only the ljaspNotch extension with this token is accepted. This token is only for the extension; Claude Code hooks use their own. After regenerating it, paste the new token into the extension's options."
          )
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 520)
    .onAppear { portText = String(settings.serverPort) }
  }

  private var extensionEnabled: Binding<Bool> {
    Binding(
      get: { [settings] in settings.browserExtensionEnabled },
      set: { [settings, server] enabled in
        settings.browserExtensionEnabled = enabled
        if enabled {
          server.startExtensionServer(port: settings.serverPort)
        } else {
          server.stopExtensionServer()
        }
      })
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

  private func applyPort() {
    guard let port = UInt16(portText), port >= 1024 else { return }
    settings.serverPort = port
    server.startExtensionServer(port: port)
  }
}
