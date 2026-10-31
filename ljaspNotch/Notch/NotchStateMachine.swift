/// Pure transition logic for the notch panel (SPEC § 6). It knows nothing about time:
/// it asks for timers through `Effect` and is told when they fire, which keeps it
/// deterministic and easy to test.
struct NotchStateMachine: Sendable {
  enum Event: Sendable {
    case pointerEntered
    case pointerExited
    case clicked
    case pinToggled
    case openDelayElapsed
    case closeDelayElapsed
    case liveActivityChanged(Bool)
    /// Close immediately, e.g. when paused or the screen goes away.
    case reset
  }

  enum Effect: Equatable, Sendable {
    case none
    case startOpenTimer
    case startCloseTimer
    case cancelTimer
  }

  private(set) var state = NotchState.closed
  private(set) var isPointerInside = false
  private(set) var hasLiveActivity = false

  /// Where the panel goes when it closes.
  private var restingState: NotchState {
    hasLiveActivity ? .peek : .closed
  }

  mutating func handle(_ event: Event) -> Effect {
    switch event {
    case .pointerEntered:
      isPointerInside = true
      switch state {
      case .closed, .peek: return .startOpenTimer
      case .expanded: return .cancelTimer
      case .pinned: return .none
      }

    case .pointerExited:
      isPointerInside = false
      switch state {
      case .closed, .peek: return .cancelTimer
      case .expanded: return .startCloseTimer
      case .pinned: return .none
      }

    case .clicked:
      guard !state.isOpen else { return .none }
      state = .expanded
      return .cancelTimer

    case .pinToggled:
      switch state {
      case .expanded:
        state = .pinned
        return .cancelTimer
      case .pinned:
        state = .expanded
        return isPointerInside ? .none : .startCloseTimer
      case .closed, .peek:
        return .none
      }

    case .openDelayElapsed:
      if !state.isOpen && isPointerInside {
        state = .expanded
      }
      return .none

    case .closeDelayElapsed:
      if state == .expanded && !isPointerInside {
        state = restingState
      }
      return .none

    case .liveActivityChanged(let active):
      hasLiveActivity = active
      if !state.isOpen {
        state = restingState
      }
      return .none

    case .reset:
      isPointerInside = false
      state = restingState
      return .cancelTimer
    }
  }
}
