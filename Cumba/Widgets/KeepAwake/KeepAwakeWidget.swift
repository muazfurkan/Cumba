import IOKit.pwr_mgt
import Observation
import SwiftUI

/// Keeps the Mac and its display awake for a while, like `caffeinate`. It holds a power
/// assertion, which the system drops when the app quits; no setting is changed.
@MainActor
@Observable
final class KeepAwakeWidget: NotchWidget {
  static let kind = "keep-awake"
  static var title: String { String(localized: "Keep Awake", comment: "Widget name") }
  static let symbol = "cup.and.saucer"
  static let size = WidgetSize.compact
  static var summary: String {
    String(
      localized: "Stops the Mac and its display from sleeping for a while",
      comment: "Widget description")
  }

  /// Lengths offered, in minutes; `nil` keeps it on until turned off.
  static let durations: [Int?] = [30, 60, 120, nil]

  private(set) var isOn = false
  /// End of a timed session; `nil` while off or on without a limit.
  private(set) var endsAt: Date?

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private var assertion = IOPMAssertionID(0)
  @ObservationIgnored private var endTask: Task<Void, Never>?

  private static let activityID = "keepAwake"

  required init(context: WidgetContext) {
    liveActivities = context.liveActivities
  }

  func makeView() -> AnyView {
    AnyView(KeepAwakeView(widget: self))
  }

  func shutdown() {
    turnOff()
  }

  func turnOn(minutes: Int?) {
    turnOff()
    var id = IOPMAssertionID(0)
    let result = IOPMAssertionCreateWithName(
      kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
      IOPMAssertionLevel(kIOPMAssertionLevelOn), "Cumba Keep Awake" as CFString, &id)
    guard result == kIOReturnSuccess else {
      Log.widgets.error("Keep Awake assertion failed: \(result, privacy: .public)")
      return
    }
    assertion = id
    isOn = true
    if let minutes {
      let seconds = minutes * 60
      endsAt = Date().addingTimeInterval(TimeInterval(seconds))
      endTask = Task { [weak self] in
        do {
          try await Task.sleep(for: .seconds(seconds))
        } catch {
          return
        }
        self?.turnOff()
      }
    }
    showActivity()
  }

  func turnOff() {
    endTask?.cancel()
    endTask = nil
    if assertion != 0 {
      IOPMAssertionRelease(assertion)
      assertion = 0
    }
    isOn = false
    endsAt = nil
    liveActivities.dismiss(Self.activityID)
  }

  private func showActivity() {
    let trailing: AnyView =
      if let endsAt {
        AnyView(
          Text(timerInterval: Date()...endsAt, countsDown: true)
            .panelFont(.caption, monospacedDigit: true)
            .multilineTextAlignment(.trailing))
      } else {
        AnyView(Text("On", comment: "Keep Awake is on").panelFont(.caption))
      }
    liveActivities.show(
      LiveActivity(
        id: Self.activityID, priority: .keepAwake,
        leading: AnyView(Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange)),
        trailing: trailing))
  }

  static func label(minutes: Int?) -> Text {
    guard let minutes else {
      return Text("Until Turned Off", comment: "Keep Awake without a time limit")
    }
    return Text(
      Duration.seconds(minutes * 60),
      format: .units(allowed: [.hours, .minutes], width: .wide))
  }
}

private struct KeepAwakeView: View {
  let widget: KeepAwakeWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 8) {
        Label("Keep Awake", systemImage: "cup.and.saucer")
          .panelFont(.caption)
          .foregroundStyle(.secondary)
        if widget.isOn {
          Group {
            if let endsAt = widget.endsAt {
              Text(timerInterval: Date()...endsAt, countsDown: true)
            } else {
              Text("On", comment: "Keep Awake is on")
            }
          }
          .panelFont(size: 22, weight: .semibold, monospacedDigit: true)
          Button("Turn Off") { widget.turnOff() }
            .controlSize(.small)
        } else {
          Image(systemName: "moon.zzz")
            .panelFont(.title2)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          Menu {
            ForEach(KeepAwakeWidget.durations, id: \.self) { minutes in
              Button {
                widget.turnOn(minutes: minutes)
              } label: {
                KeepAwakeWidget.label(minutes: minutes)
              }
            }
          } label: {
            Text("Turn On")
          }
          .menuStyle(.button)
          .controlSize(.small)
          .fixedSize()
        }
      }
    }
  }
}
