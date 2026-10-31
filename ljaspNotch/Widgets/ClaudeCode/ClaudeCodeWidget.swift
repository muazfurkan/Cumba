import Observation
import SwiftUI

/// Claude Code sessions and pending permission requests.
@MainActor
@Observable
final class ClaudeCodeWidget: NotchWidget {
  static let kind = "claude-code"
  static let title = "Claude Code"
  static let symbol = "terminal"
  static let size = WidgetSize.regular
  static var summary: String {
    String(localized: "Claude Code sessions and permission requests", comment: "Widget description")
  }

  let service: ClaudeCodeService
  private let openSettings: @MainActor (SettingsWindowController.Tab) -> Void

  required init(context: WidgetContext) {
    service = context.claude
    openSettings = context.openSettings
  }

  func makeView() -> AnyView {
    AnyView(ClaudeCodeWidgetView(service: service) { [openSettings] in openSettings(.claudeCode) })
  }
}

private struct ClaudeCodeWidgetView: View {
  let service: ClaudeCodeService
  let setUp: () -> Void

  var body: some View {
    WidgetCard {
      if let request = service.permissions.pending.first {
        PermissionCard(
          request: request, waiting: service.permissions.pending.count - 1, compact: true
        ) { decision in
          service.answer(request, with: decision)
        }
        .id(request.id)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Label("Claude Code", systemImage: "terminal")
            .font(.caption)
            .foregroundStyle(.secondary)
          if service.sessions.isEmpty {
            Text("No sessions yet. Claude Code shows up here once its hooks are installed.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Button("Set Up…", action: setUp)
              .controlSize(.small)
          } else {
            ForEach(service.sessions.prefix(3)) { session in
              SessionRow(session: session)
            }
          }
        }
      }
    }
  }
}

private struct SessionRow: View {
  let session: ClaudeCodeService.Session

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .foregroundStyle(color)
        .frame(width: 14)
      VStack(alignment: .leading, spacing: 0) {
        Text(session.project)
          .font(.caption.weight(.medium))
          .lineLimit(1)
        Text(session.detail ?? stateText)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var symbol: String {
    switch session.state {
    case .working: "ellipsis.circle"
    case .waitingPermission: "hand.raised.fill"
    case .waitingInput: "bubble.left.fill"
    case .done: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .ended: "moon.zzz"
    }
  }

  private var color: Color {
    switch session.state {
    case .working: .secondary
    case .waitingPermission, .waitingInput: .orange
    case .done: .green
    case .failed: .red
    case .ended: .secondary
    }
  }

  private var stateText: String {
    switch session.state {
    case .working: String(localized: "Working", comment: "Claude Code session state")
    case .waitingPermission:
      String(localized: "Needs permission", comment: "Claude Code session state")
    case .waitingInput: String(localized: "Waiting", comment: "Claude Code is waiting for the user")
    case .done: String(localized: "Done", comment: "Claude Code finished")
    case .failed(let error): String(localized: "Error: \(error)", comment: "Claude Code error")
    case .ended: String(localized: "Ended", comment: "Claude Code session state")
    }
  }
}

/// A permission request with Allow, Deny and "answer in the terminal". Used in the widget
/// and as a banner in the panel when the widget isn't in the visible tab.
///
/// Safety: the full request is shown, escaped (`SafeText`). Buttons stay disabled for a
/// moment whenever a new request appears, so a click aimed at something else or a double
/// click can't approve it unseen. Suspicious requests, and tools Settings exclude, get no
/// Allow button at all.
struct PermissionCard: View {
  let request: PermissionBroker.Request
  /// Requests waiting behind this one.
  let waiting: Int
  var compact = false
  let answer: (PermissionBroker.Decision) -> Void

  static let armingDelay = Duration.milliseconds(750)
  @State private var isArmed = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 6) {
      HStack(spacing: 6) {
        Image(systemName: "hand.raised.fill")
          .foregroundStyle(.orange)
        Text("\(request.project) wants to use \(request.toolName)", comment: "Permission request")
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Spacer(minLength: 0)
        if waiting > 0 {
          Text("+\(waiting)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .background(.orange.opacity(0.3), in: Capsule())
            .accessibilityLabel(Text("\(waiting) more requests waiting"))
        }
      }
      ScrollView {
        Text(request.detail)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: compact ? 44 : 64)
      .padding(6)
      .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
      if request.isSuspicious {
        Label(
          "This request has hidden characters or is too long to show safely. Answer it in the terminal.",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption2)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
      } else if !request.canAllow {
        Text("Allowing this from the notch is turned off in Settings.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      HStack(spacing: 6) {
        if request.canAllow {
          Button("Allow") { answer(.allow) }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        Button("Deny") { answer(.deny) }
          .buttonStyle(.bordered)
        Button("In Terminal") { answer(.askInTerminal) }
          .buttonStyle(.bordered)
          .help(Text("Answer in Claude Code instead"))
      }
      .controlSize(.small)
      .disabled(!isArmed)
    }
    .task(id: request.id) {
      isArmed = false
      try? await Task.sleep(for: Self.armingDelay)
      isArmed = true
    }
  }
}
