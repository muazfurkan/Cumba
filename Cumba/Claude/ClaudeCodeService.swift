import Foundation
import Observation
import SwiftUI

/// Claude Code sessions as reported by hooks, plus the live activities they cause.
/// Nothing is written to disk.
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
    /// The session's summary from its transcript, or its first prompt.
    var title: String?
    /// What it's doing now, e.g. "Editing Notch.swift"; nil when not working.
    var step: String?
    /// How full the context window was at the last answer, 0...1.
    var contextFraction: Double?
    var agent = Agent.claude
    /// Bundle identifier of the app the session runs in, from its hooks.
    var app: String?

    var isActive: Bool {
      state == .working || state == .waitingPermission
    }
  }

  /// Most recently updated first.
  private(set) var sessions: [Session] = []
  let permissions: PermissionBroker
  /// From Settings > Claude Code; applies to requests that arrive afterwards.
  var notchApprovals = NotchApprovals.all

  @ObservationIgnored let liveActivities: LiveActivityCenter
  @ObservationIgnored private var removalTasks: [String: Task<Void, Never>] = [:]
  @ObservationIgnored private var transcriptReads: [String: Date] = [:]
  /// The session and notice the status activity shows.
  @ObservationIgnored var shownNotice: (session: String, notice: AgentNotice)?

  static let permissionActivityID = "claude.permission"
  static let statusActivityID = "claude.status"
  private static let workingActivityID = "claude.working"

  init(liveActivities: LiveActivityCenter, permissions: PermissionBroker = PermissionBroker()) {
    self.liveActivities = liveActivities
    self.permissions = permissions
    permissions.onPendingChange = { [weak self] in
      self?.updatePermissionActivity()
    }
  }

  /// Handles every event except permission requests, which `requestPermission` handles.
  /// - Parameter app: Bundle identifier of the app the agent runs in, when the hook sent it.
  func handle(_ payload: HookPayload, agent: Agent = .claude, app: String? = nil) {
    guard let event = payload.event else { return }
    let id = payload.sessionID
    switch event {
    case .userPromptSubmit:
      permissions.resolveAll(in: id)
      update(id, payload, state: .working, step: AgentStep.thinking)
      if sessions.first?.title == nil, let prompt = payload.prompt {
        sessions[0].title = HookPayload.truncate(prompt, to: 60)
      }
      refreshTranscript(of: id, path: payload.transcriptPath, force: true)
    case .preToolUse:
      update(
        id, payload, state: .working,
        step: AgentStep.describe(
          toolName: payload.toolName, input: payload.toolInput, cwd: payload.cwd))
    case .postToolUse:
      update(id, payload, state: .working, step: AgentStep.thinking)
      refreshTranscript(of: id, path: payload.transcriptPath, force: false)
    case .notification:
      // A pending request or a question already shows; skip the duplicate notice.
      if payload.notificationType == "permission_prompt",
        permissions.hasPending(in: id)
          || sessions.first(where: { $0.id == id })?.state == .waitingInput
      {
        return
      }
      update(id, payload, state: .waitingInput, detail: payload.message)
      notify(
        .waiting, session: id, agent: agent, project: payload.project, message: payload.message)
    case .stop:
      permissions.resolveAll(in: id)
      let summary = payload.lastAssistantMessage.map { HookPayload.truncate($0, to: 280) }
      update(id, payload, state: .done, detail: summary)
      refreshTranscript(of: id, path: payload.transcriptPath, force: true)
      notify(.done, session: id, agent: agent, project: payload.project, message: summary)
    case .stopFailure:
      permissions.resolveAll(in: id)
      let error = payload.error ?? "unknown"
      update(id, payload, state: .failed(error), detail: payload.lastAssistantMessage)
      notify(.failed, session: id, agent: agent, project: payload.project, message: error)
    case .sessionEnd:
      permissions.resolveAll(in: id)
      update(id, payload, state: .ended)
      scheduleRemoval(of: id)
    case .permissionRequest:
      break
    }
    tag(id, with: agent, app: app)
    updateWorkingActivity()
  }

  /// Shows the request in the notch and waits for the user's decision.
  func requestPermission(_ payload: HookPayload, agent: Agent = .claude, app: String? = nil)
    async -> PermissionBroker.Decision
  {
    if payload.isQuestion {
      showQuestion(payload, agent: agent, app: app)
      return .askInTerminal
    }
    let detail = payload.permissionDetail
    let toolName = SafeText(payload.toolName ?? "?").text
    let request = PermissionBroker.Request(
      id: UUID(), sessionID: payload.sessionID, project: payload.project, toolName: toolName,
      detail: detail.text, isSuspicious: detail.isSuspicious,
      canAllow: !detail.isSuspicious && notchApprovals.allows(toolName: toolName),
      receivedAt: Date())
    update(payload.sessionID, payload, state: .waitingPermission)
    tag(payload.sessionID, with: agent, app: app)
    updateWorkingActivity()
    let decision = await permissions.decide(request)
    if !permissions.hasPending(in: payload.sessionID) {
      update(payload.sessionID, payload, state: .working, step: AgentStep.thinking)
      updateWorkingActivity()
    }
    return decision
  }

  /// A question or a plan to approve: Claude Code asks it in its own window, and the notch
  /// says so until it's answered.
  private func showQuestion(_ payload: HookPayload, agent: Agent, app: String?) {
    let question = payload.questionText.map { SafeText($0).text }
    update(payload.sessionID, payload, state: .waitingInput, detail: question)
    tag(payload.sessionID, with: agent, app: app)
    notify(
      payload.toolName == "ExitPlanMode" ? .plan : .question, session: payload.sessionID,
      agent: agent, project: payload.project, message: question)
    updateWorkingActivity()
  }

  func answer(_ request: PermissionBroker.Request, with decision: PermissionBroker.Decision) {
    permissions.resolve(request.id, with: decision)
  }

  private func update(
    _ id: String, _ payload: HookPayload, state: Session.State, detail: String? = nil,
    step: String? = nil
  ) {
    removalTasks[id]?.cancel()
    var session =
      sessions.first { $0.id == id }
      ?? Session(id: id, project: payload.project, state: state, updatedAt: Date())
    session.project = payload.project
    // A tool runs while a permission request is open only after it's answered.
    session.state = state
    session.detail = detail ?? session.detail
    session.step = state == .working ? (step ?? session.step) : nil
    session.updatedAt = Date()
    sessions.removeAll { $0.id == id }
    sessions.insert(session, at: 0)
  }

  /// Reads the context use and title from the transcript, at most every 5 seconds per
  /// session unless forced.
  private func refreshTranscript(of id: String, path: String?, force: Bool) {
    guard let url = TranscriptReader.allowedURL(path) else { return }
    let now = Date()
    if !force, let last = transcriptReads[id], now.timeIntervalSince(last) < 5 {
      return
    }
    transcriptReads[id] = now
    Task { [weak self] in
      let summary = await Task.detached { TranscriptReader.read(url) }.value
      guard let self, let summary, let index = self.sessions.firstIndex(where: { $0.id == id })
      else { return }
      if let fraction = summary.contextFraction {
        self.sessions[index].contextFraction = fraction
      }
      if let title = summary.title {
        self.sessions[index].title = title
      }
    }
  }

  private func tag(_ id: String, with agent: Agent, app: String?) {
    if let index = sessions.firstIndex(where: { $0.id == id }) {
      sessions[index].agent = agent
      sessions[index].app = app ?? sessions[index].app
    }
  }

  /// A ring beside the notch while any session works. A question stays beside the notch
  /// until its session moves on.
  private func updateWorkingActivity() {
    if let shown = shownNotice, shown.notice.waitsForUser,
      sessions.first(where: { $0.id == shown.session })?.state != .waitingInput
    {
      liveActivities.dismiss(Self.statusActivityID)
      shownNotice = nil
    }
    guard let working = sessions.first(where: { $0.state == .working }) else {
      liveActivities.dismiss(Self.workingActivityID)
      return
    }
    liveActivities.show(
      LiveActivity(
        id: Self.workingActivityID, priority: .claudeStatus,
        leading: AnyView(AgentGlyph(agent: working.agent, size: 18)),
        trailing: AnyView(AgentSpinner(agent: working.agent))))
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
}
