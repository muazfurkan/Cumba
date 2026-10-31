import AVFoundation
import Observation
import SwiftUI

/// Front camera as a mirror. The camera runs only while the widget is on screen; access is
/// requested from Settings, never from the panel.
@MainActor
@Observable
final class MirrorWidget: NotchWidget {
  static let kind = "mirror"
  static var title: String { String(localized: "Mirror", comment: "Widget name") }
  static let symbol = "web.camera"
  static let size = WidgetSize.compact

  private(set) var authorization = AVCaptureDevice.authorizationStatus(for: .video)
  @ObservationIgnored let camera = CameraSession()
  @ObservationIgnored private let openSettings: @MainActor () -> Void

  required init(context: WidgetContext) {
    openSettings = context.openSettings
  }

  func makeView() -> AnyView {
    AnyView(MirrorView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(MirrorSettingsView(widget: self))
  }

  func activate() {
    authorization = AVCaptureDevice.authorizationStatus(for: .video)
    if authorization == .authorized {
      camera.start()
    }
  }

  func deactivate() {
    camera.stop()
  }

  func shutdown() {
    camera.stop()
  }

  func requestAccess() async {
    _ = await AVCaptureDevice.requestAccess(for: .video)
    authorization = AVCaptureDevice.authorizationStatus(for: .video)
  }

  func showSettings() {
    openSettings()
  }
}

/// Owns the capture session. Every call to it runs on one private serial queue, because
/// starting and stopping a session blocks.
final class CameraSession: @unchecked Sendable {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "io.github.muazfurkan.ljaspnotch.camera")
  private var isConfigured = false

  func start() {
    queue.async { [self] in
      if !isConfigured {
        configure()
      }
      if isConfigured && !session.isRunning {
        session.startRunning()
      }
    }
  }

  func stop() {
    queue.async { [self] in
      if session.isRunning {
        session.stopRunning()
      }
    }
  }

  private func configure() {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified)
    guard let device = discovery.devices.first,
      let input = try? AVCaptureDeviceInput(device: device)
    else {
      Log.widgets.error("No camera available for the mirror")
      return
    }
    session.beginConfiguration()
    session.sessionPreset = .medium
    if session.canAddInput(input) {
      session.addInput(input)
      isConfigured = true
    }
    session.commitConfiguration()
  }
}

private struct MirrorView: View {
  let widget: MirrorWidget

  var body: some View {
    switch widget.authorization {
    case .authorized:
      CameraPreview(session: widget.camera.session)
        // A mirror shows you flipped, like a real one.
        .scaleEffect(x: -1, y: 1)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(Text("Camera mirror"))
    default:
      WidgetCard {
        VStack(alignment: .leading, spacing: 6) {
          Label("Mirror", systemImage: "web.camera")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Allow in Settings") { widget.showSettings() }
            .controlSize(.small)
        }
      }
    }
  }
}

private struct CameraPreview: NSViewRepresentable {
  let session: AVCaptureSession

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    view.layer = layer
    view.wantsLayer = true
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct MirrorSettingsView: View {
  let widget: MirrorWidget

  var body: some View {
    switch widget.authorization {
    case .authorized:
      Label("Camera access granted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .notDetermined:
      Button("Allow Camera Access") {
        Task { await widget.requestAccess() }
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        Text("Camera access was denied. You can allow it in System Settings.")
          .foregroundStyle(.secondary)
        Button("Open Privacy Settings") {
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
          {
            NSWorkspace.shared.open(url)
          }
        }
      }
    }
  }
}
