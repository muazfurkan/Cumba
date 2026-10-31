import Foundation

/// Security checks for requests to the local server (SPEC § 12). Pure functions so every
/// rule is unit tested.
enum RequestGuard {
  enum Rejection: Equatable, Sendable {
    /// Host header isn't 127.0.0.1 or localhost on our port: a DNS rebinding attempt.
    case badHost
    /// Sent by a web page; only the Chrome extension may connect.
    case badOrigin
    /// Missing or wrong token.
    case badToken
  }

  static let tokenHeader = "X-LjaspNotch-Token"

  /// Accepts only Host values that point at the loopback address on `port`. A web page
  /// that rebinds its own domain to 127.0.0.1 still sends its domain as Host.
  static func checkHost(_ host: String?, port: UInt16) -> Rejection? {
    guard let host = host?.lowercased() else { return .badHost }
    let allowed = ["127.0.0.1:\(port)", "localhost:\(port)"]
    return allowed.contains(host) ? nil : .badHost
  }

  /// Hooks from Claude Code send no Origin. Browsers always do; then only an extension
  /// page is allowed, never a website.
  static func checkHookOrigin(_ origin: String?) -> Rejection? {
    guard let origin, !origin.isEmpty else { return nil }
    return origin.hasPrefix("chrome-extension://") ? nil : .badOrigin
  }

  /// The media socket is for the extension only.
  static func checkSocketOrigin(_ origin: String?) -> Rejection? {
    guard let origin, origin.hasPrefix("chrome-extension://") else { return .badOrigin }
    return nil
  }

  static func checkToken(_ provided: String?, expected: String) -> Rejection? {
    guard let provided, !expected.isEmpty, constantTimeEquals(provided, expected) else {
      return .badToken
    }
    return nil
  }

  /// Compares without returning early, so response times don't leak how much matched.
  static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    var difference = UInt8(left.count == right.count ? 0 : 1)
    for index in 0..<max(left.count, right.count) {
      let a = index < left.count ? left[index] : 0
      let b = index < right.count ? right[index] : 0
      difference |= a ^ b
    }
    return difference == 0
  }
}
