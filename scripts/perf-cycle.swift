// Opens and closes the notch panel of a running Debug build N times, for performance and
// leak checks. Debug builds listen for these notifications; release builds ignore them.
//
//   xcrun swift scripts/perf-cycle.swift [cycles] [interval-seconds]
import Foundation

let cycles = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 100 : 100
let interval = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 0.6 : 0.6
let center = DistributedNotificationCenter.default()
let open = Notification.Name("io.github.muazfurkan.ljaspnotch.debug.open")
let close = Notification.Name("io.github.muazfurkan.ljaspnotch.debug.close")

for index in 1...cycles {
  center.postNotificationName(open, object: nil, userInfo: nil, deliverImmediately: true)
  Thread.sleep(forTimeInterval: interval)
  center.postNotificationName(close, object: nil, userInfo: nil, deliverImmediately: true)
  Thread.sleep(forTimeInterval: interval)
  if index % 25 == 0 {
    print("cycles: \(index)")
  }
}
