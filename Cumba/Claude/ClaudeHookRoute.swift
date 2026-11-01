import FlyingFox
import Foundation

/// `POST /claude/hook` on the app's private Unix socket: every Claude Code hook event
/// arrives here and is dispatched by `hook_event_name`. Only processes of this
/// user can reach the socket; the token is still required, and any browser Origin is
/// rejected. Claude Code treats every failure as non-blocking, so Claude keeps working
/// when the app is closed or a request is rejected.
struct ClaudeHookRoute: HTTPHandler {
  let token: String
  let service: ClaudeCodeService
  /// `/claude/hook` or `/codex/hook`: Codex hooks send the same events in the same shape.
  var agent = Agent.claude

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    if request.headers[HTTPHeader("Origin")] != nil {
      return HTTPResponse(statusCode: .forbidden)
    }
    if RequestGuard.checkToken(
      request.headers[HTTPHeader(RequestGuard.tokenHeader)], expected: token) != nil
    {
      return HTTPResponse(statusCode: .unauthorized)
    }
    let body = try await request.bodyData
    guard let payload = HookPayload.decode(body), let event = payload.event else {
      return HTTPResponse(statusCode: .badRequest)
    }
    Log.claude.info("Hook event: \(event.rawValue, privacy: .public)")

    switch event {
    case .permissionRequest:
      let decision = await service.requestPermission(payload, agent: agent)
      let body = PermissionBroker.responseBody(for: decision)
      // An empty 200 lets Claude Code show its own dialog.
      return HTTPResponse(
        statusCode: .ok, headers: body.isEmpty ? [:] : [.contentType: "application/json"],
        body: body)
    default:
      // UserPromptSubmit blocks the model, so answer before doing any work.
      Task { @MainActor [agent] in service.handle(payload, agent: agent) }
      return HTTPResponse(statusCode: .ok)
    }
  }
}
