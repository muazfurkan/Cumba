import Observation
import SwiftUI

/// Claude Code sessions and pending permission requests (SPEC § 9).
@MainActor
@Observable
final class ClaudeCodeWidget: NotchWidget {
  static let kind = "claude-code"
  static let title = "Claude Code"
  static let symbol = "terminal"

  let size = WidgetSize.regular
  let service: ClaudeCodeService

  required init(context: WidgetContext) {
    service = context.claude
  }

  func makeView() -> AnyView {
    AnyView(ClaudeCodeWidgetView(service: service))
  }
}

private struct ClaudeCodeWidgetView: View {
  let service: ClaudeCodeService

  var body: some View {
    WidgetCard {
      if let request = service.permissions.pending.first {
        PermissionCard(
          request: request, waiting: service.permissions.pending.count - 1, compact: true
        ) { decision in
          service.answer(request, with: decision)
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Label("Claude Code", systemImage: "terminal")
            .font(.caption)
            .foregroundStyle(.secondary)
          if service.sessions.isEmpty {
            Text("No sessions yet. Install the hooks in Settings > Claude Code.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
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
struct PermissionCard: View {
  let request: PermissionBroker.Request
  /// Requests waiting behind this one.
  let waiting: Int
  var compact = false
  let answer: (PermissionBroker.Decision) -> Void

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
      Text(request.summary)
        .font(.system(.caption, design: .monospaced))
        .lineLimit(compact ? 2 : 3)
        .textSelection(.enabled)
      HStack(spacing: 6) {
        Button("Allow") { answer(.allow) }
          .buttonStyle(.borderedProminent)
          .tint(.green)
        Button("Deny") { answer(.deny) }
          .buttonStyle(.bordered)
        Button("In Terminal") { answer(.askInTerminal) }
          .buttonStyle(.bordered)
          .help(Text("Answer in Claude Code instead"))
      }
      .controlSize(.small)
    }
  }
}
