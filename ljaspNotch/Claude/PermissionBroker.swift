import Foundation
import Observation

/// Holds Claude Code permission requests until the user answers in the notch.
/// Each request keeps its HTTP response waiting; it is answered with the
/// user's decision, or with "ask in the terminal" before the hook times out.
@MainActor
@Observable
final class PermissionBroker {
  struct Request: Identifiable, Equatable, Sendable {
    let id: UUID
    let sessionID: String
    let project: String
    let toolName: String
    /// Everything the request would do, escaped (see `SafeText`).
    let detail: String
    /// Hidden characters or truncation found; Allow isn't offered then.
    let isSuspicious: Bool
    /// False when the request is suspicious or Settings turn off Allow for this tool.
    let canAllow: Bool
    let receivedAt: Date
  }

  enum Decision: Equatable, Sendable {
    case allow
    case deny
    /// Empty response: Claude Code continues with its own permission dialog.
    case askInTerminal
  }

  /// Oldest first; the notch shows the first one and the count.
  private(set) var pending: [Request] = [] {
    didSet { onPendingChange?() }
  }
  /// Called whenever a request arrives or is answered, also by timeout.
  @ObservationIgnored var onPendingChange: (() -> Void)?
  @ObservationIgnored private var continuations: [UUID: CheckedContinuation<Decision, Never>] = [:]
  @ObservationIgnored private let timeout: Duration

  /// The hook timeout is 300 s; answer 10 s earlier so Claude Code gets an answer.
  init(timeout: Duration = .seconds(290)) {
    self.timeout = timeout
  }

  /// Waits for the user's decision. Returns `.askInTerminal` on timeout or when the
  /// waiting task is cancelled, e.g. because Claude Code closed the connection.
  func decide(_ request: Request) async -> Decision {
    pending.append(request)
    let timeoutTask = Task { [weak self, timeout] in
      try? await Task.sleep(for: timeout)
      self?.resolve(request.id, with: .askInTerminal)
    }
    let decision = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        continuations[request.id] = continuation
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.resolve(request.id, with: .askInTerminal) }
    }
    timeoutTask.cancel()
    return decision
  }

  func resolve(_ id: UUID, with decision: Decision) {
    // Allow reaches Claude Code only for a request that offered it.
    let canAllow = pending.first { $0.id == id }?.canAllow == true
    let decision = decision == .allow && !canAllow ? .askInTerminal : decision
    pending.removeAll { $0.id == id }
    continuations.removeValue(forKey: id)?.resume(returning: decision)
  }

  /// A later event of the same session means its open requests were answered elsewhere.
  func resolveAll(in sessionID: String) {
    for request in pending where request.sessionID == sessionID {
      resolve(request.id, with: .askInTerminal)
    }
  }

  func hasPending(in sessionID: String) -> Bool {
    pending.contains { $0.sessionID == sessionID }
  }

  /// Body of the HTTP response for a decision.
  nonisolated static func responseBody(for decision: Decision) -> Data {
    let behavior: String
    switch decision {
    case .allow: behavior = "allow"
    case .deny: behavior = "deny"
    case .askInTerminal: return Data()
    }
    var decisionObject: [String: Any] = ["behavior": behavior]
    if decision == .deny {
      decisionObject["message"] = "Denied in ljaspNotch."
    }
    let object: [String: Any] = [
      "hookSpecificOutput": [
        "hookEventName": "PermissionRequest",
        "decision": decisionObject,
      ]
    ]
    return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
  }
}
