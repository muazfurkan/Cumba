import Foundation
import Observation

/// Drives the notch panel: feeds events to `NotchStateMachine` and runs its timers.
@MainActor
@Observable
final class NotchViewModel {
  private(set) var state = NotchState.closed
  /// Size of the hardware notch on the current screen; the view sizes its shapes from it.
  var geometry: NotchGeometry?

  /// Called after every state change, e.g. to update the hover area.
  @ObservationIgnored var onStateChange: ((NotchState) -> Void)?

  @ObservationIgnored private var machine = NotchStateMachine()
  @ObservationIgnored private var timer: Task<Void, Never>?
  @ObservationIgnored private let openDelay: Duration
  @ObservationIgnored private let closeDelay: Duration

  init(openDelay: Duration = .milliseconds(150), closeDelay: Duration = .milliseconds(400)) {
    self.openDelay = openDelay
    self.closeDelay = closeDelay
  }

  func send(_ event: NotchStateMachine.Event) {
    switch machine.handle(event) {
    case .none:
      break
    case .cancelTimer:
      cancelTimer()
    case .startOpenTimer:
      startTimer(after: openDelay, then: .openDelayElapsed)
    case .startCloseTimer:
      startTimer(after: closeDelay, then: .closeDelayElapsed)
    }
    if machine.state != state {
      state = machine.state
      onStateChange?(state)
    }
  }

  private func startTimer(after delay: Duration, then event: NotchStateMachine.Event) {
    cancelTimer()
    timer = Task { [weak self] in
      do {
        try await Task.sleep(for: delay)
      } catch {
        return
      }
      self?.send(event)
    }
  }

  private func cancelTimer() {
    timer?.cancel()
    timer = nil
  }
}
