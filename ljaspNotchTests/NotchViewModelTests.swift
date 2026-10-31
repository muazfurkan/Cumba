import Testing

@testable import ljaspNotch

/// Checks that the view model runs the state machine's timers. Transition rules
/// themselves are covered by NotchStateMachineTests.
@MainActor
struct NotchViewModelTests {
  @Test func hoverOpensAndLeavingCloses() async throws {
    let model = NotchViewModel(openDelay: .milliseconds(10), closeDelay: .milliseconds(10))
    var changes: [NotchState] = []
    model.onStateChange = { changes.append($0) }

    model.send(.pointerEntered)
    #expect(model.state == .closed)
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.state == .expanded)

    model.send(.pointerExited)
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.state == .closed)
    #expect(changes == [.expanded, .closed])
  }

  @Test func leavingEarlyCancelsTheOpenTimer() async throws {
    let model = NotchViewModel(openDelay: .milliseconds(50), closeDelay: .milliseconds(10))
    model.send(.pointerEntered)
    model.send(.pointerExited)
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.state == .closed)
  }
}
