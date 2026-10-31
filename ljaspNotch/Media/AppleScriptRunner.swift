import AppKit
import CoreServices

/// Runs AppleScript for the music players. NSAppleScript isn't thread-safe, so every call
/// goes through this actor, whose executor is one serial queue; nothing runs on the main
/// thread.
actor AppleScriptRunner {
  enum Failure: Error, Equatable {
    /// The app isn't running. Scripts are never sent then, because that would launch it.
    case notRunning
    /// The user hasn't answered the Automation prompt yet.
    case needsPermission
    /// The user denied Automation access in System Settings.
    case denied
    case scriptError(code: Int, message: String)
  }

  enum Permission: Equatable, Sendable {
    case granted
    case notDetermined
    case denied
  }

  static let shared = AppleScriptRunner()

  private let queue = DispatchSerialQueue(label: "io.github.muazfurkan.ljaspnotch.applescript")
  private var compiled: [String: NSAppleScript] = [:]

  nonisolated var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  nonisolated static func isRunning(_ bundleID: String) -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
  }

  /// Checks Automation access without asking, or asks with the system prompt. Ask only
  /// from the Settings window, so the prompt can't appear behind the panel.
  func permission(for bundleID: String, ask: Bool) -> Permission {
    guard Self.isRunning(bundleID) else { return .notDetermined }
    let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
    let status = AEDeterminePermissionToAutomateTarget(
      target.aeDesc, typeWildCard, typeWildCard, ask)
    switch Int(status) {
    case Int(noErr): return .granted
    case Int(errAEEventNotPermitted): return .denied
    default: return .notDetermined
    }
  }

  /// Runs `source` in the app with `bundleID` and converts the result with `parse`.
  /// Never launches the app and never shows the Automation prompt.
  func run<Result: Sendable>(
    _ source: String,
    in bundleID: String,
    parse: @Sendable (NSAppleEventDescriptor) -> Result
  ) throws(Failure) -> Result {
    guard Self.isRunning(bundleID) else { throw .notRunning }
    switch permission(for: bundleID, ask: false) {
    case .granted: break
    case .notDetermined: throw .needsPermission
    case .denied: throw .denied
    }
    let script = compiled[source] ?? NSAppleScript(source: source)
    guard let script else { throw .scriptError(code: 0, message: "Invalid script") }
    compiled[source] = script
    var errorInfo: NSDictionary?
    let result = script.executeAndReturnError(&errorInfo)
    if let errorInfo {
      let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
      if code == Int(errAEEventNotPermitted) {
        throw .denied
      }
      throw .scriptError(
        code: code, message: errorInfo[NSAppleScript.errorMessage] as? String ?? "")
    }
    return parse(result)
  }
}

extension NSAppleEventDescriptor {
  /// Items of a list result; a single value is a list of one.
  var listItems: [NSAppleEventDescriptor] {
    guard numberOfItems > 0 else { return [self] }
    return (1...numberOfItems).compactMap { atIndex($0) }
  }
}
