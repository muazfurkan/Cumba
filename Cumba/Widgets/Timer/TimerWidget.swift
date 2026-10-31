import AppKit
import Observation
import SwiftUI

/// Countdown timer / pomodoro. It keeps running while the panel is closed: one task sleeps
/// until the end time, so there is no polling. Running and finished timers show as live
/// activities.
@MainActor
@Observable
final class TimerWidget: NotchWidget {
  static let kind = "timer"
  static var title: String { String(localized: "Timer", comment: "Widget name") }
  static let symbol = "timer"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "A countdown that keeps running when the panel closes",
      comment: "Widget description")
  }
  static let addedByDefault = true

  enum Phase: Equatable {
    case idle
    case running(endsAt: Date)
    case paused(remaining: TimeInterval)
    case finished
  }

  /// Preset lengths in minutes.
  static let presets = [5, 15, 25, 50]

  private(set) var phase = Phase.idle
  /// Length of the timer in seconds.
  private(set) var length: TimeInterval = 25 * 60

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private var endTask: Task<Void, Never>?

  private static let runningActivityID = "timer.running"
  private static let finishedActivityID = "timer.finished"

  required init(context: WidgetContext) {
    liveActivities = context.liveActivities
  }

  func makeView() -> AnyView {
    AnyView(TimerWidgetView(timer: self))
  }

  func shutdown() {
    reset()
  }

  // MARK: - Controls

  func select(minutes: Int) {
    guard !isActive else { return }
    length = TimeInterval(minutes * 60)
    phase = .idle
    liveActivities.dismiss(Self.finishedActivityID)
  }

  func start() {
    let remaining =
      switch phase {
      case .paused(let remaining): remaining
      default: length
      }
    let endsAt = Date().addingTimeInterval(remaining)
    phase = .running(endsAt: endsAt)
    liveActivities.dismiss(Self.finishedActivityID)
    showRunningActivity(endsAt: endsAt)
    endTask?.cancel()
    endTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(remaining))
      } catch {
        return
      }
      self?.finish()
    }
  }

  func pause() {
    guard case .running(let endsAt) = phase else { return }
    endTask?.cancel()
    phase = .paused(remaining: max(0, endsAt.timeIntervalSinceNow))
    liveActivities.dismiss(Self.runningActivityID)
  }

  func reset() {
    endTask?.cancel()
    phase = .idle
    liveActivities.dismiss(Self.runningActivityID)
    liveActivities.dismiss(Self.finishedActivityID)
  }

  var isActive: Bool {
    switch phase {
    case .running, .paused: true
    case .idle, .finished: false
    }
  }

  private func finish() {
    phase = .finished
    liveActivities.dismiss(Self.runningActivityID)
    NSSound(named: NSSound.Name("Glass"))?.play()
    liveActivities.show(
      LiveActivity(
        id: Self.finishedActivityID, priority: .timerFinished,
        leading: AnyView(Image(systemName: "timer").foregroundStyle(.orange)),
        trailing: AnyView(
          Text("Done", comment: "Timer finished").panelFont(.caption, weight: .bold))),
      for: .seconds(10))
  }

  private func showRunningActivity(endsAt: Date) {
    liveActivities.show(
      LiveActivity(
        id: Self.runningActivityID, priority: .timerRunning,
        leading: AnyView(Image(systemName: "timer")),
        trailing: AnyView(
          Text(timerInterval: Date()...endsAt, countsDown: true)
            .panelFont(.caption, monospacedDigit: true)
            .multilineTextAlignment(.trailing))))
  }
}

private struct TimerWidgetView: View {
  let timer: TimerWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 8) {
        Label("Timer", systemImage: "timer")
          .panelFont(.caption)
          .foregroundStyle(.secondary)
        countdown
          .panelFont(size: 30, weight: .semibold, monospacedDigit: true)
        HStack(spacing: 6) {
          if timer.isActive {
            controlButton(
              timer.phase == .idle || isPaused ? "play.fill" : "pause.fill",
              label: isPaused ? Text("Resume") : Text("Pause")
            ) {
              isPaused ? timer.start() : timer.pause()
            }
            controlButton("arrow.counterclockwise", label: Text("Reset")) { timer.reset() }
          } else {
            // With large text the units don't fit; the bare numbers do.
            ViewThatFits(in: .horizontal) {
              presets(withUnit: true)
              presets(withUnit: false)
            }
            Spacer(minLength: 4)
            controlButton("play.fill", label: Text("Start")) { timer.start() }
          }
        }
      }
    }
  }

  private var isPaused: Bool {
    if case .paused = timer.phase { true } else { false }
  }

  private func presets(withUnit: Bool) -> some View {
    HStack(spacing: 2) {
      ForEach(TimerWidget.presets, id: \.self) { minutes in
        Button {
          timer.select(minutes: minutes)
        } label: {
          Group {
            if withUnit {
              Text("\(minutes)m", comment: "Timer preset in minutes")
            } else {
              Text(minutes, format: .number)
            }
          }
          .panelFont(.caption, monospacedDigit: true)
          .lineLimit(1)
          .fixedSize()
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(
            timer.length == TimeInterval(minutes * 60) ? .white.opacity(0.2) : .clear,
            in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(minutes)m", comment: "Timer preset in minutes"))
      }
    }
  }

  @ViewBuilder private var countdown: some View {
    switch timer.phase {
    case .running(let endsAt):
      Text(timerInterval: Date()...endsAt, countsDown: true)
    case .paused(let remaining):
      Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
    case .idle:
      Text(Duration.seconds(timer.length), format: .time(pattern: .minuteSecond))
    case .finished:
      Text("Done", comment: "Timer finished")
    }
  }

  private func controlButton(_ symbol: String, label: Text, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(PanelButtonStyle(isSelected: true))
    .accessibilityLabel(label)
    .help(label)
  }
}
