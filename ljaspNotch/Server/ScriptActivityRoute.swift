import FlyingFox
import Foundation
import SwiftUI

/// `POST /activity` on the private Unix socket: lets your own scripts (a build, a backup,
/// a Shortcut) show a short status beside the notch. Off until turned on in Settings >
/// Connections, with its own token. Text is escaped like permission requests and shown
/// read-only, so a script can't make it look like anything you'd click.
///
///     { "id": "build", "title": "Build done", "symbol": "hammer", "progress": 0.4,
///       "duration": 10 }
///     { "id": "build", "remove": true }
struct ScriptActivityRoute: HTTPHandler {
  let token: String
  let isEnabled: @Sendable @MainActor () -> Bool
  let liveActivities: LiveActivityCenter

  /// Largest accepted body.
  static let maxBodySize = 4_096

  struct Message: Decodable, Equatable, Sendable {
    var id: String?
    var title: String?
    var symbol: String?
    var progress: Double?
    var duration: Double?
    var remove: Bool?
  }

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    if request.headers[HTTPHeader("Origin")] != nil {
      return HTTPResponse(statusCode: .forbidden)
    }
    guard await isEnabled() else { return HTTPResponse(statusCode: .notFound) }
    if RequestGuard.checkToken(
      request.headers[HTTPHeader(RequestGuard.tokenHeader)], expected: token) != nil
    {
      return HTTPResponse(statusCode: .unauthorized)
    }
    let body = try await request.bodyData
    guard body.count <= Self.maxBodySize,
      let message = try? JSONDecoder().decode(Message.self, from: body),
      let activity = ScriptActivity(message)
    else { return HTTPResponse(statusCode: .badRequest) }
    await MainActor.run { activity.apply(to: liveActivities) }
    return HTTPResponse(statusCode: .noContent)
  }
}

/// A validated script message.
struct ScriptActivity: Equatable, Sendable {
  let id: String
  let title: String
  let symbol: String
  let progress: Double?
  let duration: Double
  let isRemoval: Bool

  static let idPrefix = "script."
  static let durationRange = 1.0...3_600
  static let maxTitleLength = 60

  /// Nil when the message is unusable (no title, bad id).
  init?(_ message: ScriptActivityRoute.Message) {
    let id = message.id ?? "default"
    guard (1...40).contains(id.count),
      id.unicodeScalars.allSatisfy({
        CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0)
      })
    else { return nil }
    self.id = Self.idPrefix + id
    isRemoval = message.remove == true
    let title = SafeText(message.title ?? "").text
    guard isRemoval || !title.isEmpty else { return nil }
    self.title = String(title.prefix(Self.maxTitleLength))
    let symbol = message.symbol ?? "terminal"
    self.symbol =
      symbol.count <= 60 && NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil
      ? symbol : "terminal"
    progress = message.progress.map { min(max($0, 0), 1) }
    duration = (message.duration ?? 10).clamped(to: Self.durationRange)
  }

  @MainActor
  func apply(to center: LiveActivityCenter) {
    guard !isRemoval else {
      center.dismiss(id)
      return
    }
    let trailing: AnyView =
      if let progress {
        AnyView(
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .frame(width: 44)
            .accessibilityLabel(Text(verbatim: title)))
      } else {
        AnyView(Text(verbatim: title).font(.caption).lineLimit(1))
      }
    center.show(
      LiveActivity(
        id: id, priority: .script,
        leading: AnyView(Image(systemName: symbol).help(Text(verbatim: title))),
        trailing: trailing),
      for: .seconds(duration))
  }
}
