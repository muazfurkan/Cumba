import Testing

@testable import Cumba

struct NotchStateMachineTests {
  /// Builds a machine and feeds it the given events.
  private func machine(after events: [NotchStateMachine.Event]) -> NotchStateMachine {
    var machine = NotchStateMachine()
    for event in events {
      _ = machine.handle(event)
    }
    return machine
  }

  @Test func startsClosed() {
    #expect(NotchStateMachine().state == .closed)
  }

  @Test func hoverOpensAfterTheDelay() {
    var machine = NotchStateMachine()
    #expect(machine.handle(.pointerEntered) == .startOpenTimer)
    #expect(machine.state == .closed)
    _ = machine.handle(.openDelayElapsed)
    #expect(machine.state == .expanded)
  }

  @Test func leavingBeforeTheOpenDelayKeepsItClosed() {
    var machine = machine(after: [.pointerEntered])
    #expect(machine.handle(.pointerExited) == .cancelTimer)
    _ = machine.handle(.openDelayElapsed)
    #expect(machine.state == .closed)
  }

  @Test func movingInsideRestartsTheOpenDelay() {
    var machine = machine(after: [.pointerEntered])
    #expect(machine.handle(.pointerMoved) == .startOpenTimer)
    #expect(machine.state == .closed)
  }

  @Test func movingOutsideOrWhileOpenDoesNothing() {
    var outside = NotchStateMachine()
    #expect(outside.handle(.pointerMoved) == .none)
    var open = machine(after: [.pointerEntered, .openDelayElapsed])
    #expect(open.handle(.pointerMoved) == .none)
  }

  @Test func leavingClosesAfterTheDelay() {
    var machine = machine(after: [.pointerEntered, .openDelayElapsed])
    #expect(machine.handle(.pointerExited) == .startCloseTimer)
    #expect(machine.state == .expanded)
    _ = machine.handle(.closeDelayElapsed)
    #expect(machine.state == .closed)
  }

  @Test func returningBeforeTheCloseDelayKeepsItOpen() {
    var machine = machine(after: [.pointerEntered, .openDelayElapsed, .pointerExited])
    #expect(machine.handle(.pointerEntered) == .cancelTimer)
    _ = machine.handle(.closeDelayElapsed)
    #expect(machine.state == .expanded)
  }

  @Test func clickOnlyModeIgnoresHover() {
    var machine = NotchStateMachine()
    machine.opensOnHover = false
    #expect(machine.handle(.pointerEntered) == .none)
    #expect(machine.handle(.pointerMoved) == .none)
    _ = machine.handle(.clicked)
    #expect(machine.state == .expanded)
    #expect(machine.handle(.pointerExited) == .startCloseTimer)
  }

  @Test func anOpenNotificationKeepsHoverFromOpeningThePanel() {
    var machine = NotchStateMachine()
    _ = machine.handle(.liveActivityChanged(true))
    machine.isShowingNotification = true
    #expect(machine.handle(.pointerEntered) == .none)
    #expect(machine.handle(.pointerMoved) == .none)
    machine.isShowingNotification = false
    #expect(machine.handle(.pointerMoved) == .startOpenTimer)
  }

  @Test func clickOpensImmediately() {
    var machine = machine(after: [.pointerEntered])
    #expect(machine.handle(.clicked) == .cancelTimer)
    #expect(machine.state == .expanded)
  }

  @Test func pinnedPanelIgnoresThePointer() {
    var machine = machine(after: [.clicked, .pinToggled])
    #expect(machine.state == .pinned)
    #expect(machine.handle(.pointerExited) == .none)
    _ = machine.handle(.closeDelayElapsed)
    #expect(machine.state == .pinned)
  }

  @Test func unpinningWithPointerOutsideStartsClosing() {
    var machine = machine(after: [.pointerEntered, .clicked, .pinToggled, .pointerExited])
    #expect(machine.handle(.pinToggled) == .startCloseTimer)
    #expect(machine.state == .expanded)
    _ = machine.handle(.closeDelayElapsed)
    #expect(machine.state == .closed)
  }

  @Test func unpinningWithPointerInsideStaysOpen() {
    var machine = machine(after: [.pointerEntered, .clicked, .pinToggled])
    #expect(machine.handle(.pinToggled) == .none)
    #expect(machine.state == .expanded)
  }

  @Test func liveActivityPeeksAndClosesBackToPeek() {
    var machine = machine(after: [.liveActivityChanged(true)])
    #expect(machine.state == .peek)
    for event: NotchStateMachine.Event in [
      .pointerEntered, .openDelayElapsed, .pointerExited, .closeDelayElapsed,
    ] {
      _ = machine.handle(event)
    }
    #expect(machine.state == .peek)
    _ = machine.handle(.liveActivityChanged(false))
    #expect(machine.state == .closed)
  }

  @Test func liveActivityDoesNotCloseAnOpenPanel() {
    let machine = machine(after: [.clicked, .liveActivityChanged(true)])
    #expect(machine.state == .expanded)
  }

  @Test func resetClosesEvenWhenPinned() {
    var machine = machine(after: [.pointerEntered, .clicked, .pinToggled])
    #expect(machine.handle(.reset) == .cancelTimer)
    #expect(machine.state == .closed)
    #expect(!machine.isPointerInside)
  }

  @Test func staleTimersAreIgnored() {
    let opened = machine(after: [.openDelayElapsed])
    #expect(opened.state == .closed)
    let closed = machine(after: [.clicked, .pointerEntered, .closeDelayElapsed])
    #expect(closed.state == .expanded)
  }
}
