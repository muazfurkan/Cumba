import FlyingFox
import Foundation

/// `POST /claude/hook`: every Claude Code hook event arrives here and is dispatched by
/// `hook_event_name` (SPEC § 9). Requires a loopback Host, no website Origin and the token
/// header; answers 401/403 otherwise. Claude Code treats any failure as non-blocking, so
/// Claude keeps working when the app is closed or the request is rejected.
struct ClaudeHookRoute: HTTPHandler {
  let port: UInt16
  let token: String
  let service: ClaudeCodeService

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    if RequestGuard.checkHost(request.headers[.host], port: port) != nil
      || RequestGuard.checkHookOrigin(request.headers[HTTPHeader("Origin")]) != nil
    {
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
      let decision = await service.requestPermission(payload)
      let body = PermissionBroker.responseBody(for: decision)
      // An empty 200 lets Claude Code show its own dialog.
      return HTTPResponse(
        statusCode: .ok, headers: body.isEmpty ? [:] : [.contentType: "application/json"],
        body: body)
    default:
      // UserPromptSubmit blocks the model, so answer before doing any work.
      Task { @MainActor in service.handle(payload) }
      return HTTPResponse(statusCode: .ok)
    }
  }
}
