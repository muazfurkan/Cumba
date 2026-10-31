import FlyingFox
import Foundation
import Testing

@testable import ljaspNotch

private func fixture(_ name: String) throws -> Data {
  let url = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Fixtures/claude/\(name).json")
  return try Data(contentsOf: url)
}

struct HookPayloadTests {
  @Test(arguments: [
    "permission-request-bash", "permission-request-edit", "user-prompt-submit",
    "notification-idle", "notification-permission", "stop", "stop-failure", "session-end",
  ])
  func decodesEveryFixture(name: String) throws {
    let payload = try #require(HookPayload.decode(try fixture(name)))
    #expect(payload.sessionID == "session-1")
    #expect(payload.event != nil)
    #expect(payload.project == "demo")
  }

  @Test func summarizesBashAndEdits() throws {
    let bash = try #require(HookPayload.decode(try fixture("permission-request-bash")))
    #expect(bash.permissionSummary == "rm -rf node_modules")
    let edit = try #require(HookPayload.decode(try fixture("permission-request-edit")))
    #expect(edit.permissionSummary == "Sources/App.swift")
  }

  @Test func longCommandsAreCutToOneLine() {
    let text = HookPayload.truncate(String(repeating: "a\n", count: 200), to: 20)
    #expect(text.count == 20)
    #expect(!text.contains("\n"))
  }

  @Test func rejectsOversizedAndInvalidBodies() {
    #expect(HookPayload.decode(Data("nope".utf8)) == nil)
    #expect(HookPayload.decode(Data(count: HookPayload.maxBodySize + 1)) == nil)
  }
}

@MainActor
struct PermissionBrokerTests {
  private func request(session: String = "s") -> PermissionBroker.Request {
    PermissionBroker.Request(
      id: UUID(), sessionID: session, project: "demo", toolName: "Bash", summary: "ls",
      receivedAt: .now)
  }

  @Test func userDecisionIsReturned() async {
    let broker = PermissionBroker()
    let request = request()
    async let decision = broker.decide(request)
    while broker.pending.isEmpty {
      await Task.yield()
    }
    broker.resolve(request.id, with: .allow)
    #expect(await decision == .allow)
    #expect(broker.pending.isEmpty)
  }

  @Test func timeoutFallsBackToTheTerminal() async {
    let broker = PermissionBroker(timeout: .milliseconds(30))
    #expect(await broker.decide(request()) == .askInTerminal)
    #expect(broker.pending.isEmpty)
  }

  @Test func laterSessionEventsClearStaleRequests() async {
    let broker = PermissionBroker()
    async let first = broker.decide(request(session: "a"))
    async let other = broker.decide(request(session: "b"))
    while broker.pending.count < 2 {
      await Task.yield()
    }
    broker.resolveAll(in: "a")
    #expect(await first == .askInTerminal)
    #expect(broker.pending.map(\.sessionID) == ["b"])
    broker.resolveAll(in: "b")
    _ = await other
  }

  @Test func responseBodiesMatchTheHookFormat() throws {
    let allow = try JSONSerialization.jsonObject(with: PermissionBroker.responseBody(for: .allow))
    let output = (allow as? [String: Any])?["hookSpecificOutput"] as? [String: Any]
    #expect(output?["hookEventName"] as? String == "PermissionRequest")
    #expect((output?["decision"] as? [String: Any])?["behavior"] as? String == "allow")
    let deny = String(decoding: PermissionBroker.responseBody(for: .deny), as: UTF8.self)
    #expect(deny.contains(#""behavior":"deny""#))
    #expect(PermissionBroker.responseBody(for: .askInTerminal).isEmpty)
  }
}

@MainActor
struct ClaudeCodeServiceTests {
  private func payload(_ name: String) throws -> HookPayload {
    try #require(HookPayload.decode(try fixture(name)))
  }

  @Test func sessionFollowsTheEvents() throws {
    let center = LiveActivityCenter()
    let service = ClaudeCodeService(liveActivities: center)
    service.handle(try payload("user-prompt-submit"))
    #expect(service.sessions.first?.state == .working)
    service.handle(try payload("stop"))
    #expect(service.sessions.first?.state == .done)
    #expect(service.sessions.first?.detail == "I've completed the refactoring.")
    #expect(center.current?.priority == .claudeStatus)
    service.handle(try payload("stop-failure"))
    #expect(service.sessions.first?.state == .failed("rate_limit"))
    service.handle(try payload("session-end"))
    #expect(service.sessions.first?.state == .ended)
  }

  @Test func permissionShowsAndAnswerResolves() async throws {
    let center = LiveActivityCenter()
    let service = ClaudeCodeService(liveActivities: center)
    let request = try payload("permission-request-bash")
    async let decision = service.requestPermission(request)
    while service.permissions.pending.isEmpty {
      await Task.yield()
    }
    #expect(center.current?.priority == .claudePermission)
    #expect(service.sessions.first?.state == .waitingPermission)
    // The duplicate notification for the same prompt is ignored.
    service.handle(try payload("notification-permission"))
    #expect(service.sessions.first?.state == .waitingPermission)
    service.answer(try #require(service.permissions.pending.first), with: .deny)
    #expect(await decision == .deny)
    #expect(center.current?.priority != .claudePermission)
  }
}

@MainActor
struct ClaudeHookRouteTests {
  private let token = String(repeating: "c", count: 64)

  private func request(_ body: Data, token: String?, origin: String? = nil, host: String? = nil)
    -> HTTPRequest
  {
    var headers: HTTPHeaders = [.host: host ?? "127.0.0.1:47823"]
    if let token {
      headers[HTTPHeader(RequestGuard.tokenHeader)] = token
    }
    if let origin {
      headers[HTTPHeader("Origin")] = origin
    }
    return HTTPRequest(
      method: .POST, version: .http11, path: "/claude/hook", query: [], headers: headers,
      body: HTTPBodySequence(data: body))
  }

  private func route() -> ClaudeHookRoute {
    ClaudeHookRoute(
      port: 47823, token: token, service: ClaudeCodeService(liveActivities: LiveActivityCenter()))
  }

  @Test func rejectsMissingOrWrongTokens() async throws {
    let body = try fixture("stop")
    #expect(try await route().handleRequest(request(body, token: nil)).statusCode == .unauthorized)
    #expect(
      try await route().handleRequest(request(body, token: "x")).statusCode == .unauthorized)
  }

  @Test func rejectsWebsitesAndRebinding() async throws {
    let body = try fixture("stop")
    let fromWebsite = request(body, token: token, origin: "https://evil.example")
    #expect(try await route().handleRequest(fromWebsite).statusCode == .forbidden)
    let rebound = request(body, token: token, host: "evil.example:47823")
    #expect(try await route().handleRequest(rebound).statusCode == .forbidden)
  }

  @Test func acceptsValidEventsAndRejectsGarbage() async throws {
    let ok = try await route().handleRequest(request(try fixture("stop"), token: token))
    #expect(ok.statusCode == .ok)
    let bad = try await route().handleRequest(request(Data("{}".utf8), token: token))
    #expect(bad.statusCode == .badRequest)
  }
}
