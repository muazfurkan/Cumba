import SwiftUI

/// Live activity on both sides of the closed notch.
struct PeekView: View {
  let activity: LiveActivity
  let notchWidth: CGFloat
  let sideWidth: CGFloat
  let height: CGFloat
  /// Opens the panel, for a notification without an action that can run.
  var openPanel: () -> Void = {}

  var body: some View {
    VStack(spacing: 0) {
      row
        .frame(height: height)
        .accessibilityElement(children: .combine)
      if let notification = activity.notification {
        NotificationCard(notification: notification, openPanel: openPanel)
          .frame(height: NotchLayout.notificationHeight, alignment: .top)
          .transition(.opacity)
      }
    }
    .panelFont(.caption)
    .environment(\.peekHeight, height)
    // Beside the notch there is no room to grow, so the text size setting doesn't apply.
    .environment(\.panelTextScale, 1)
  }

  private var row: some View {
    HStack(spacing: 0) {
      // Clipped to the side, so nothing can slide under the camera housing where it can't
      // be seen; the full height keeps strokes and glyph edges whole.
      activity.leading
        .frame(width: sideWidth, height: height)
        .clipped()
      Color.clear
        .frame(width: notchWidth)
      activity.trailing
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: sideWidth, height: height)
        .clipped()
    }
  }
}

extension EnvironmentValues {
  /// Height of the closed notch, so live activities can size their content to it.
  @Entry var peekHeight: CGFloat = 32
  /// The widget is alone in its tab and has room for its detailed view; with others it
  /// shows a compact summary.
  @Entry var showsDetailedWidget = false
}
