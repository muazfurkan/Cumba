import IOKit.ps

/// The internal battery, from IOKit power source notifications (no polling). Nil on Macs
/// without a battery.
@MainActor
final class BatteryMonitor {
  var onChange: ((BatteryWidget.Status?) -> Void)?

  private var source: CFRunLoopSource?

  func start() {
    guard source == nil else { return }
    let context = Unmanaged.passUnretained(self).toOpaque()
    // The callback runs on the main run loop. The monitor lives as long as the app.
    let callback: IOPowerSourceCallbackType = { context in
      guard let context else { return }
      let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { monitor.refresh() }
    }
    guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue()
    else {
      Log.app.error("Battery notifications are unavailable")
      return
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    self.source = source
    refresh()
  }

  func stop() {
    if let source {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
    }
    source = nil
  }

  private func refresh() {
    Task {
      let status = await Task.detached { BatteryWidget.readStatus() }.value
      guard source != nil else { return }
      onChange?(status)
    }
  }
}

extension BatteryWidget.Status {
  /// On battery at or below the low level, the way the notch warns about it.
  var isLow: Bool {
    !isPluggedIn && percent <= BatteryWidget.lowBatteryPercent
  }
}
