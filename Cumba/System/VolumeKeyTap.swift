import AppKit
import ApplicationServices

/// Optional: handles the volume keys itself so the notch shows the change instead of the
/// system indicator. It needs Accessibility access for an event tap, which sees only the
/// media key events it asks for (`NX_SYSDEFINED`), never typing. Keys it can't handle,
/// e.g. on an output without volume control, pass through to macOS unchanged.
@MainActor
final class VolumeKeyTap {
  private let volume: VolumeMonitor
  private var tap: CFMachPort?
  private var source: CFRunLoopSource?

  /// `NX_SYSDEFINED`, the event type of media keys.
  private static let systemDefinedType = CGEventType(rawValue: 14)
  private static let auxControlButtons: Int16 = 8
  private static let soundUp = 0
  private static let soundDown = 1
  private static let mute = 7
  /// macOS changes the volume in sixteenths, and in quarters of that with Shift-Option.
  private static let step: Float = 1 / 16

  init(volume: VolumeMonitor) {
    self.volume = volume
  }

  static var isTrusted: Bool { AXIsProcessTrusted() }

  /// Shows the system prompt that leads to Accessibility settings. Call from Settings.
  static func requestAccess() {
    let key = "AXTrustedCheckOptionPrompt" as CFString
    _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
  }

  /// Returns false without Accessibility access.
  @discardableResult
  func start() -> Bool {
    guard tap == nil else { return true }
    guard Self.isTrusted, let type = Self.systemDefinedType else { return false }
    let mask = CGEventMask(1) << CGEventMask(type.rawValue)
    // The tap's run loop source is on the main run loop, so this runs on the main thread.
    let callback: CGEventTapCallBack = { _, type, event, refcon in
      guard let refcon else { return Unmanaged.passUnretained(event) }
      let tap = Unmanaged<VolumeKeyTap>.fromOpaque(refcon).takeUnretainedValue()
      nonisolated(unsafe) let unsafeEvent = event
      let swallow = MainActor.assumeIsolated { tap.handle(type: type, event: unsafeEvent) }
      return swallow ? nil : Unmanaged.passUnretained(event)
    }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: mask, callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { return false }
    let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    self.source = source
    return true
  }

  func stop() {
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
    }
    if let source {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    tap = nil
    source = nil
  }

  /// Returns true to swallow the event.
  private func handle(type: CGEventType, event: CGEvent) -> Bool {
    // macOS turns a slow tap off; turn it back on.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return false
    }
    guard type == Self.systemDefinedType, let nsEvent = NSEvent(cgEvent: event),
      nsEvent.subtype.rawValue == Self.auxControlButtons, volume.canSetVolume
    else { return false }
    let keyCode = (nsEvent.data1 & 0xFFFF_0000) >> 16
    let isDown = (nsEvent.data1 & 0xFF00) >> 8 == 0xA
    guard [Self.soundUp, Self.soundDown, Self.mute].contains(keyCode) else { return false }
    if isDown, let level = volume.level {
      let fine = nsEvent.modifierFlags.contains([.shift, .option])
      let step = fine ? Self.step / 4 : Self.step
      switch keyCode {
      case Self.soundUp: volume.setVolume(level.volume + step)
      case Self.soundDown: volume.setVolume(level.volume - step)
      default: volume.setMuted(!level.isMuted)
      }
    }
    // Swallow both key down and up, so the system indicator doesn't appear.
    return true
  }
}
