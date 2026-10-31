import Foundation
import Observation
import SwiftUI

/// Claude Code sessions as reported by hooks, plus the live activities they cause
/// (SPEC § 9). Nothing is written to disk.
@MainActor
@Observable
final class ClaudeCodeService {
  struct Session: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
      case working
      case waitingPermission
      case waitingInput
      case done
      case failed(String)
      case ended
    }

    let id: String
    var project: String
    var state: State
    /// Short summary of the last answer or error.
    var detail: String?
    var updatedAt: Date
  }

  /// Most recently updated first.
  private(set) var sessions: [Session] = []
  let permissions: PermissionBroker

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private var removalTasks: [String: Task<Void, Never>] = [:]

  private static let permissionActivityID = "claude.permission"
  private static let statusActivityID = "claude.status"

  init(liveActivities: LiveActivityCenter, permissions: PermissionBroker = PermissionBroker()) {
    self.liveActivities = liveActivities
    self.permissions = permissions
    permissions.onPendingChange = { [weak self] in
      self?.updatePermissionActivity()
    }
  }

  /// Handles every event except permission requests, which `requestPermission` handles.
  func handle(_ payload: HookPayload) {
    guard let event = payload.event else { return }
    let id = payload.sessionID
    switch event {
    case .userPromptSubmit:
      permissions.resolveAll(in: id)
      update(id, project: payload.project, state: .working, detail: nil)
    case .notification:
      // A pending request already shows; skip the duplicate "needs permission" notice.
      if payload.notificationType == "permission_prompt" && permissions.hasPending(in: id) {
        return
      }
      update(id, project: payload.project, state: .waitingInput, detail: payload.message)
      showStatus(
        symbol: "bubble.left.fill", color: .orange, project: payload.project,
        text: String(localized: "Waiting", comment: "Claude Code is waiting for the user"))
    case .stop:
      permissions.resolveAll(in: id)
      let summary = payload.lastAssistantMessage.map { HookPayload.truncate($0, to: 140) }
      update(id, project: payload.project, state: .done, detail: summary)
      showStatus(
        symbol: "checkmark.circle.fill", color: .green, project: payload.project,
        text: String(localized: "Done", comment: "Claude Code finished"))
    case .stopFailure:
      permissions.resolveAll(in: id)
      let error = payload.error ?? "unknown"
      update(
        id, project: payload.project, state: .failed(error), detail: payload.lastAssistantMessage)
      showStatus(
        symbol: "exclamationmark.triangle.fill", color: .red, project: payload.project,
        text: String(localized: "Error", comment: "Claude Code stopped with an error"))
    case .sessionEnd:
      permissions.resolveAll(in: id)
      update(id, project: payload.project, state: .ended, detail: nil)
      scheduleRemoval(of: id)
    case .permissionRequest:
      break
    }
  }

  /// Shows the request in the notch and waits for the user's decision.
  func requestPermission(_ payload: HookPayload) async -> PermissionBroker.Decision {
    let request = PermissionBroker.Request(
      id: UUID(), sessionID: payload.sessionID, project: payload.project,
      toolName: payload.toolName ?? "?", summary: payload.permissionSummary, receivedAt: Date())
    update(payload.sessionID, project: payload.project, state: .waitingPermission, detail: nil)
    let decision = await permissions.decide(request)
    if !permissions.hasPending(in: payload.sessionID) {
      update(payload.sessionID, project: payload.project, state: .working, detail: nil)
    }
    return decision
  }

  func answer(_ request: PermissionBroker.Request, with decision: PermissionBroker.Decision) {
    permissions.resolve(request.id, with: decision)
  }

  private func update(_ id: String, project: String, state: Session.State, detail: String?) {
    removalTasks[id]?.cancel()
    var session =
      sessions.first { $0.id == id }
      ?? Session(id: id, project: project, state: state, updatedAt: Date())
    session.project = project
    session.state = state
    session.detail = detail ?? (state == .working ? nil : session.detail)
    session.updatedAt = Date()
    sessions.removeAll { $0.id == id }
    sessions.insert(session, at: 0)
  }

  /// Ended sessions leave the list after a minute.
  private func scheduleRemoval(of id: String) {
    removalTasks[id] = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(60))
      } catch {
        return
      }
      self?.sessions.removeAll { $0.id == id && $0.state == .ended }
      self?.removalTasks[id] = nil
    }
  }

  private func updatePermissionActivity() {
    guard let first = permissions.pending.first else {
      liveActivities.dismiss(Self.permissionActivityID)
      return
    }
    let count = permissions.pending.count
    liveActivities.show(
      LiveActivity(
        id: Self.permissionActivityID, priority: .claudePermission,
        leading: AnyView(Image(systemName: "hand.raised.fill").foregroundStyle(.orange)),
        trailing: AnyView(
          Text(count > 1 ? "\(first.toolName) +\(count - 1)" : first.toolName)
            .font(.caption.weight(.semibold)))))
  }

  private func showStatus(symbol: String, color: Color, project: String, text: String) {
    liveActivities.show(
      LiveActivity(
        id: Self.statusActivityID, priority: .claudeStatus,
        leading: AnyView(Image(systemName: symbol).foregroundStyle(color)),
        trailing: AnyView(
          Text(project).font(.caption.weight(.medium)).help(text).accessibilityLabel(
            Text("\(project): \(text)")))),
      for: .seconds(4))
  }
}
