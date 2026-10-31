import IOKit.ps
import Observation
import SwiftUI

/// Battery level from IOKit power source notifications (no polling). Plugging in the
/// charger and a low battery show as short live activities.
@MainActor
@Observable
final class BatteryWidget: NotchWidget {
  static let kind = "battery"
  static var title: String { String(localized: "Battery", comment: "Widget name") }
  static let symbol = "battery.75percent"

  struct Status: Equatable, Sendable {
    var percent: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    /// Minutes until full while charging, until empty otherwise. Nil while estimating.
    var minutesRemaining: Int?
  }

  static let lowBatteryPercent = 20

  /// Nil on Macs without a battery.
  private(set) var status: Status?
  let size = WidgetSize.compact

  @ObservationIgnored private let liveActivities: LiveActivityCenter
  @ObservationIgnored private var runLoopSource: CFRunLoopSource?

  required init(context: WidgetContext) {
    liveActivities = context.liveActivities
    startMonitoring()
  }

  func makeView() -> AnyView {
    AnyView(BatteryWidgetView(battery: self))
  }

  func shutdown() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
    }
    runLoopSource = nil
    liveActivities.dismiss("battery")
  }

  private func startMonitoring() {
    let context = Unmanaged.passUnretained(self).toOpaque()
    // The callback runs on the main run loop.
    let callback: IOPowerSourceCallbackType = { context in
      guard let context else { return }
      let widget = Unmanaged<BatteryWidget>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { widget.refresh() }
    }
    guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue()
    else {
      Log.widgets.error("Battery notifications are unavailable")
      return
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    runLoopSource = source
    refresh()
  }

  private func refresh() {
    Task {
      let new = await Task.detached { Self.readStatus() }.value
      update(to: new)
    }
  }

  private func update(to new: Status?) {
    let old = status
    status = new
    guard let old, let new else { return }
    if new.isPluggedIn && !old.isPluggedIn {
      showActivity(new, symbol: "bolt.fill", color: .green)
    } else if !new.isPluggedIn && new.percent <= Self.lowBatteryPercent
      && old.percent > Self.lowBatteryPercent
    {
      showActivity(new, symbol: "battery.25percent", color: .red)
    }
  }

  private func showActivity(_ status: Status, symbol: String, color: Color) {
    liveActivities.show(
      LiveActivity(
        id: "battery", priority: .battery,
        leading: AnyView(Image(systemName: symbol).foregroundStyle(color)),
        trailing: AnyView(
          Text(Double(status.percent) / 100, format: .percent).font(.caption.monospacedDigit()))),
      for: .seconds(3))
  }

  /// Reads the internal battery. Runs off the main thread.
  nonisolated static func readStatus() -> Status? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
    else { return nil }
    for source in sources {
      guard
        let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
          as? [String: Any],
        description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
      else { continue }
      let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
      let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
      let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
      let minutesKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
      let minutes = description[minutesKey] as? Int ?? -1
      return Status(
        percent: maximum > 0 ? current * 100 / maximum : current,
        isCharging: isCharging,
        isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
        minutesRemaining: minutes >= 0 ? minutes : nil)
    }
    return nil
  }
}

private struct BatteryWidgetView: View {
  let battery: BatteryWidget

  var body: some View {
    WidgetCard {
      VStack(alignment: .leading, spacing: 6) {
        Label("Battery", systemImage: "battery.75percent")
          .font(.caption)
          .foregroundStyle(.secondary)
        if let status = battery.status {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Double(status.percent) / 100, format: .percent)
              .font(.system(size: 26, weight: .semibold).monospacedDigit())
            if status.isCharging {
              Image(systemName: "bolt.fill").foregroundStyle(.green)
            }
          }
          Image(systemName: symbol(for: status))
            .font(.title2)
            .foregroundStyle(status.percent <= BatteryWidget.lowBatteryPercent ? .red : .primary)
            .accessibilityHidden(true)
          if let minutes = status.minutesRemaining {
            let time = Duration.seconds(minutes * 60).formatted(.units(width: .abbreviated))
            Group {
              if status.isCharging {
                Text("\(time) to full", comment: "Battery charging time")
              } else {
                Text("\(time) left", comment: "Battery time remaining")
              }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
        } else {
          Text("No battery")
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func symbol(for status: BatteryWidget.Status) -> String {
    if status.isPluggedIn && status.isCharging {
      return "battery.100percent.bolt"
    }
    switch status.percent {
    case 88...: return "battery.100percent"
    case 63..<88: return "battery.75percent"
    case 38..<63: return "battery.50percent"
    case 13..<38: return "battery.25percent"
    default: return "battery.0percent"
    }
  }
}
