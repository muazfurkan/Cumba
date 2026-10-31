import CoreGraphics
import Foundation

/// The built-in display's brightness. Apple silicon Macs have no public API for it, so this
/// loads the private DisplayServices framework at run time; when it or a function is
/// missing, brightness features just stay unavailable. Changes arrive as notifications,
/// without polling or any permission. Lives as long as the app.
@MainActor
final class BrightnessMonitor {
  /// Called with the new level when it changes by at least `minimumStep`.
  var onChange: ((Float) -> Void)?

  /// Smaller steps come from automatic brightness adjusting slowly, not from the keys
  /// (sixteenths), so they don't show the indicator.
  static let minimumStep: Float = 1 / 40

  private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
  private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
  private typealias Callback =
    @convention(c) (
      CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?,
      CFDictionary?
    ) -> Void
  private typealias Register =
    @convention(c) (CGDirectDisplayID, UnsafeRawPointer?, Callback) -> Int32

  private struct API {
    let get: Get
    let set: Set
    let register: Register
  }

  private let api: API?
  private var registered = false
  private var isRunning = false
  private var lastLevel: Float?

  init() {
    guard
      let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
      let get = dlsym(handle, "DisplayServicesGetBrightness"),
      let set = dlsym(handle, "DisplayServicesSetBrightness"),
      let register = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications")
    else {
      api = nil
      return
    }
    api = API(
      get: unsafeBitCast(get, to: Get.self), set: unsafeBitCast(set, to: Set.self),
      register: unsafeBitCast(register, to: Register.self))
  }

  /// The built-in display, or nil when there is none or the lid is closed.
  private var display: CGDirectDisplayID? {
    var displays = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return nil }
    return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
  }

  var isAvailable: Bool { api != nil && display != nil }

  var level: Float? {
    guard let api, let display else { return nil }
    var value: Float = 0
    return api.get(display, &value) == 0 ? value : nil
  }

  func setLevel(_ value: Float) {
    guard let api, let display else { return }
    _ = api.set(display, min(max(value, 0), 1))
  }

  func start() {
    isRunning = true
    lastLevel = level
    guard !registered, let api, let display else { return }
    // The registration can't be removed again, so `stop()` only mutes it.
    let callback: Callback = { _, observer, _, _, _ in
      guard let observer else { return }
      let monitor = Unmanaged<BrightnessMonitor>.fromOpaque(observer).takeUnretainedValue()
      DispatchQueue.main.async {
        MainActor.assumeIsolated { monitor.changed() }
      }
    }
    registered =
      api.register(display, Unmanaged.passUnretained(self).toOpaque(), callback) == 0
  }

  func stop() {
    isRunning = false
    lastLevel = nil
  }

  private func changed() {
    guard isRunning, let level else { return }
    defer { lastLevel = level }
    if let lastLevel, abs(level - lastLevel) < Self.minimumStep {
      return
    }
    onChange?(level)
  }
}
