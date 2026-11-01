import SwiftUI

/// What an agent wants the user to know, shown as a notification under the notch that then
/// folds into the agent's mark and a badge beside it.
enum AgentNotice: Equatable, Sendable {
  case question
  /// A plan waiting for approval (ExitPlanMode).
  case plan
  case waiting
  case permission
  case done
  case failed

  /// The notification's title, which says what kind of notice it is.
  func title(for agent: Agent) -> String {
    let name = agent.name
    return switch self {
    case .question:
      String(
        localized: "\(name) is asking a question",
        comment: "Notification title; the argument is an AI agent's name")
    case .plan:
      String(
        localized: "\(name) has a plan for you to review",
        comment: "Notification title; the argument is an AI agent's name")
    case .waiting:
      String(
        localized: "\(name) is waiting for you",
        comment: "Notification title; the argument is an AI agent's name")
    case .permission:
      String(
        localized: "\(name) needs your permission",
        comment: "Notification title; the argument is an AI agent's name")
    case .done:
      String(
        localized: "\(name) is done",
        comment: "Notification title; the argument is an AI agent's name")
    case .failed:
      String(
        localized: "\(name) stopped with an error",
        comment: "Notification title; the argument is an AI agent's name")
    }
  }

  /// The badge on the notification's icon.
  var symbol: String {
    switch self {
    case .question, .plan: "questionmark"
    case .waiting: "ellipsis"
    case .permission: "hand.raised.fill"
    case .done: "checkmark"
    case .failed: "exclamationmark"
    }
  }

  /// Beside the closed notch once the notification folds.
  var peekSymbol: String {
    switch self {
    case .question, .plan: "questionmark.bubble.fill"
    case .waiting: "ellipsis.bubble.fill"
    case .permission: "hand.raised.fill"
    case .done: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    }
  }

  var color: Color {
    switch self {
    case .question, .plan, .waiting, .permission: .orange
    case .done: .green
    case .failed: .red
    }
  }

  /// Stays beside the notch until the user answers; the others go away on their own.
  var waitsForUser: Bool {
    switch self {
    case .question, .plan, .permission: true
    case .waiting, .done, .failed: false
    }
  }
}
