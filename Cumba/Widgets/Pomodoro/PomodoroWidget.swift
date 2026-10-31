import AppKit
import Observation
import SwiftUI

/// Focus and break rounds: a focus round, then a short break, and a long break after every
/// fourth round. Like the timer, one task sleeps until the end of a round, so nothing polls
/// while the panel is closed. Finished focus rounds are counted per day.
@MainActor
@Observable
final class PomodoroWidget: NotchWidget {
  static let kind = "pomodoro"
  static var title: String { String(localized: "Pomodoro", comment: "Widget name") }
  static let symbol = "target"
  static let size = WidgetSize.regular
  static var summary: String {
    String(
      localized: "Focus rounds with short and long breaks, counted per day",
      comment: "Widget description")
  }

  enum Round: Equatable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .focus }
    var symbol: String { isBreak ? "leaf" : "target" }

    var name: String {
      switch self {
      case .focus: String(localized: "Focus", comment: "Pomodoro round")
      case .shortBreak: String(localized: "Short Break", comment: "Pomodoro round")
      case .longBreak: String(localized: "Long Break", comment: "Pomodoro round")
      }
    }
  }

  enum State: Equatable {
    case idle
    case running(endsAt: Date)
    case paused(remaining: TimeInterval)
  }

  static let roundsPerSet = 4

  private(set) var round = Round.focus
  private(set) var state = State.idle
  /// Focus rounds finished in the current set (0–3).
  private(set) var finishedInSet = 0
  private(set) var finishedToday: Int

  var focusMinutes: Int {
    didSet { defaults.set(focusMinutes, forKey: Key.focus) }
  }
  var shortBreakMinutes: Int {
    didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreak) }
  }
  var longBreakMinutes: Int {
    didSet { defaults.set(longBreakMinutes, forKey: Key.longBreak) }
  }
  /// Starts the next round on its own when one ends.
  var continuesAutomatically: Bool {
    didSet { defaults.set(continuesAutomatically, forKey: Key.continues) }
  }

  private enum Key {
    static let focus = "pomodoro.focusMinutes"
    static let shortBreak = "pomodoro.shortBreakMinutes"
    static let longBreak = "pomodoro.longBreakMinutes"
    static let continues = "pomodoro.continuesAutomatically"
    static let countPrefix = "pomodoro.finished."
  }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private var endTask: Task<Void, Never>?

  private static let runningActivityID = "pomodoro.running"
  private static let endedActivityID = "pomodoro.ended"

  required convenience init(context: WidgetContext) {
    self.init(defaults: .standard, liveActivities: context.liveActivities)
  }

  init(defaults: UserDefaults, liveActivities: LiveActivityCenter) {
    self.defaults = defaults
    self.liveActivities = liveActivities
    focusMinutes = defaults.object(forKey: Key.focus) as? Int ?? 25
    shortBreakMinutes = defaults.object(forKey: Key.shortBreak) as? Int ?? 5
    longBreakMinutes = defaults.object(forKey: Key.longBreak) as? Int ?? 15
    continuesAutomatically = defaults.object(forKey: Key.continues) as? Bool ?? true
    finishedToday = defaults.integer(forKey: Self.countKey(for: .now))
  }

  func makeView() -> AnyView {
    AnyView(PomodoroView(widget: self))
  }

  func makeSettingsView() -> AnyView? {
    AnyView(PomodoroSettingsView(widget: self))
  }

  func shutdown() {
    reset()
  }

  // MARK: - Controls

  var length: TimeInterval {
    let minutes =
      switch round {
      case .focus: focusMinutes
      case .shortBreak: shortBreakMinutes
      case .longBreak: longBreakMinutes
      }
    return TimeInterval(minutes * 60)
  }

  func start() {
    let remaining =
      switch state {
      case .paused(let remaining): remaining
      default: length
      }
    let endsAt = Date().addingTimeInterval(remaining)
    state = .running(endsAt: endsAt)
    liveActivities.dismiss(Self.endedActivityID)
    showRunningActivity(endsAt: endsAt)
    endTask?.cancel()
    endTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(remaining))
      } catch {
        return
      }
      self?.roundEnded()
    }
  }

  func pause() {
    guard case .running(let endsAt) = state else { return }
    endTask?.cancel()
    state = .paused(remaining: max(0, endsAt.timeIntervalSinceNow))
    liveActivities.dismiss(Self.runningActivityID)
  }

  /// Ends the current round early without counting it.
  func skip() {
    let wasRunning = state != .idle
    endTask?.cancel()
    advance(countingFocus: false)
    if wasRunning {
      start()
    }
  }

  func reset() {
    endTask?.cancel()
    state = .idle
    round = .focus
    finishedInSet = 0
    liveActivities.dismiss(Self.runningActivityID)
    liveActivities.dismiss(Self.endedActivityID)
  }

  // MARK: - Rounds

  private func roundEnded() {
    let ended = round
    advance(countingFocus: true)
    NSSound(named: NSSound.Name("Glass"))?.play()
    let text =
      ended == .focus
      ? Text("Break time", comment: "Pomodoro focus round ended")
      : Text("Back to focus", comment: "Pomodoro break ended")
    liveActivities.show(
      LiveActivity(
        id: Self.endedActivityID, priority: .timerFinished,
        leading: AnyView(Image(systemName: round.symbol).foregroundStyle(.orange)),
        trailing: AnyView(text.panelFont(.caption, weight: .bold))),
      for: .seconds(8))
    if continuesAutomatically {
      start()
    }
  }

  /// Moves to the next round; a finished focus round counts when `countingFocus`.
  func advance(countingFocus: Bool) {
    state = .idle
    liveActivities.dismiss(Self.runningActivityID)
    switch round {
    case .focus:
      if countingFocus {
        finishedInSet += 1
        finishedToday = defaults.integer(forKey: Self.countKey(for: .now)) + 1
        defaults.set(finishedToday, forKey: Self.countKey(for: .now))
      }
      round = finishedInSet >= Self.roundsPerSet ? .longBreak : .shortBreak
    case .shortBreak:
      round = .focus
    case .longBreak:
      finishedInSet = 0
      round = .focus
    }
  }

  private func showRunningActivity(endsAt: Date) {
    liveActivities.show(
      LiveActivity(
        id: Self.runningActivityID, priority: .timerRunning,
        leading: AnyView(Image(systemName: round.symbol)),
        trailing: AnyView(
          Text(timerInterval: Date()...endsAt, countsDown: true)
            .panelFont(.caption, monospacedDigit: true)
            .multilineTextAlignment(.trailing))))
  }

  static func countKey(for date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return Key.countPrefix
      + "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }
}

private struct PomodoroView: View {
  let widget: PomodoroWidget

  var body: some View {
    WidgetCard(tint: widget.round.isBreak ? .green : nil) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label(widget.round.name, systemImage: widget.round.symbol)
            .panelFont(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          HStack(spacing: 4) {
            ForEach(0..<PomodoroWidget.roundsPerSet, id: \.self) { index in
              Circle()
                .fill(
                  index < widget.finishedInSet ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary)
                )
                .frame(width: 6, height: 6)
            }
          }
          .accessibilityElement()
          .accessibilityLabel(
            Text(
              "\(widget.finishedInSet) of \(PomodoroWidget.roundsPerSet) rounds",
              comment: "Pomodoro progress"))
        }
        countdown
          .panelFont(size: 30, weight: .semibold, monospacedDigit: true)
        HStack(spacing: 6) {
          controlButton(
            isRunning ? "pause.fill" : "play.fill",
            label: isRunning ? Text("Pause") : Text("Start")
          ) {
            isRunning ? widget.pause() : widget.start()
          }
          controlButton("forward.end.fill", label: Text("Skip")) { widget.skip() }
          controlButton("arrow.counterclockwise", label: Text("Reset")) { widget.reset() }
          Spacer()
          Text("Today: \(widget.finishedToday)", comment: "Finished pomodoro rounds today")
            .panelFont(.caption, monospacedDigit: true)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var isRunning: Bool {
    if case .running = widget.state { true } else { false }
  }

  @ViewBuilder private var countdown: some View {
    switch widget.state {
    case .running(let endsAt):
      Text(timerInterval: Date()...endsAt, countsDown: true)
    case .paused(let remaining):
      Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
    case .idle:
      Text(Duration.seconds(widget.length), format: .time(pattern: .minuteSecond))
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

private struct PomodoroSettingsView: View {
  @Bindable var widget: PomodoroWidget

  var body: some View {
    Stepper(value: $widget.focusMinutes, in: 5...90, step: 5) {
      LabeledContent("Focus", value: minutes(widget.focusMinutes))
    }
    Stepper(value: $widget.shortBreakMinutes, in: 1...30) {
      LabeledContent("Short Break", value: minutes(widget.shortBreakMinutes))
    }
    Stepper(value: $widget.longBreakMinutes, in: 5...60, step: 5) {
      LabeledContent("Long Break", value: minutes(widget.longBreakMinutes))
    }
    Toggle("Start the next round automatically", isOn: $widget.continuesAutomatically)
  }

  private func minutes(_ value: Int) -> String {
    Duration.seconds(value * 60).formatted(.units(allowed: [.minutes], width: .abbreviated))
  }
}
