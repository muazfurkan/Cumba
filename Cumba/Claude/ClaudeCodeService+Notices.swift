import AppKit
import SwiftUI

/// Notifications under the notch for what an agent session wants the user to know.
extension ClaudeCodeService {
  /// A request waiting in the panel: a notification that leads to it, then the agent's mark
  /// and a raised hand beside the notch until it's answered.
  func updatePermissionActivity() {
    guard let first = permissions.pending.first else {
      liveActivities.dismiss(Self.permissionActivityID)
      return
    }
    let count = permissions.pending.count
    let agent = sessions.first { $0.id == first.sessionID }?.agent ?? .claude
    let tool = HookPayload.shortToolName(first.toolName)
    let notification = LiveNotification(
      icon: AnyView(AgentNoticeIcon(agent: agent, notice: .permission)),
      title: AgentNotice.permission.title(for: agent),
      message: Self.oneLine(first.detail.isEmpty ? tool : "\(tool): \(first.detail)"),
      context: first.project,
      // Answered in the panel, which this opens.
      action: LiveNotification.Action(
        title: String(localized: "Review", comment: "Notification button: opens the request")
      ) { false },
      tint: agent.color, duration: .seconds(10))
    liveActivities.show(
      LiveActivity(
        id: Self.permissionActivityID, priority: .claudePermission,
        leading: AnyView(AgentGlyph(agent: agent, size: 18)),
        trailing: AnyView(
          HStack(spacing: 4) {
            AgentNoticeBadge(agent: agent, notice: .permission)
            if count > 1 {
              Text(verbatim: "+\(count - 1)").font(.caption.weight(.semibold))
            }
          }),
        notification: notification))
  }

  /// A notification under the notch that then folds into the agent's mark and a badge.
  /// Questions stay until answered; the rest go away a few seconds after folding.
  func notify(
    _ notice: AgentNotice, session id: String, agent: Agent, project: String, message: String?
  ) {
    let notification = LiveNotification(
      icon: AnyView(AgentNoticeIcon(agent: agent, notice: notice)),
      title: notice.title(for: agent),
      message: message.map(Self.oneLine),
      context: project,
      action: LiveNotification.Action(
        title: String(localized: "Open", comment: "Notification button: shows the agent's app")
      ) { [weak self] in self?.openApp(of: id) ?? false },
      tint: agent.color,
      duration: notice.waitsForUser ? .seconds(10) : .seconds(6))
    liveActivities.show(
      LiveActivity(
        id: Self.statusActivityID, priority: .claudeStatus,
        leading: AnyView(AgentGlyph(agent: agent, size: 18)),
        trailing: AnyView(AgentNoticeBadge(agent: agent, notice: notice)),
        notification: notification),
      for: notice.waitsForUser ? nil : .seconds(4))
    shownNotice = (id, notice)
  }

  /// Brings the app the session runs in to the front if it's running; never launches one.
  /// False when it isn't known or isn't running.
  func openApp(of id: String) -> Bool {
    guard let bundleID = sessions.first(where: { $0.id == id })?.app,
      let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    else { return false }
    return app.activate()
  }

  /// One line of at most 160 characters, for a notification.
  static func oneLine(_ text: String) -> String {
    let words = text.split(whereSeparator: \.isWhitespace)
    return HookPayload.truncate(words.joined(separator: " "), to: 160)
  }
}
