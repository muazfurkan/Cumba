import SwiftUI

/// A notification that opens under the notch for a few seconds and then folds back into the
/// live activity beside the notch: what happened as a title, one line of detail, and one
/// action.
struct LiveNotification {
  struct Action {
    let title: String
    /// Returns false when it couldn't act, e.g. the app is no longer running; the panel
    /// opens instead.
    let perform: @MainActor () -> Bool
  }

  let icon: AnyView
  let title: String
  var message: String?
  /// Small text after the title, e.g. the project.
  var context: String?
  var action: Action?
  /// The action button's color.
  var tint: Color = .white
  /// How long it stays open; the pointer resting on it keeps it open longer.
  var duration: Duration = .seconds(6)
}

/// The notification's card: icon, title and detail, and the action as a capsule button.
struct NotificationCard: View {
  let notification: LiveNotification
  /// Opens the panel when there's no action or the action couldn't run.
  let openPanel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      notification.icon
        .frame(width: 40, height: 40)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(verbatim: notification.title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .layoutPriority(1)
          if let context = notification.context {
            Text(verbatim: context)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white.opacity(0.4))
          }
        }
        .lineLimit(1)
        if let message = notification.message {
          Text(verbatim: message)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      Spacer(minLength: 8)
      if let action = notification.action {
        Button(action.title) {
          if !action.perform() {
            openPanel()
          }
        }
        .buttonStyle(NotificationButtonStyle(tint: notification.tint))
      }
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct NotificationButtonStyle: ButtonStyle {
  let tint: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.black.opacity(0.85))
      .padding(.horizontal, 16)
      .frame(height: 30)
      .background(tint.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
      .contentShape(Capsule())
  }
}
