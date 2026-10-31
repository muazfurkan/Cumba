import Darwin
import SwiftUI

/// This app's own CPU and memory use, the way Activity Monitor shows them.
enum ResourceUsage {
  /// User and system CPU time of this process so far, in seconds.
  static func cpuTime() -> TimeInterval {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    func seconds(_ time: timeval) -> TimeInterval {
      TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000
    }
    return seconds(usage.ru_utime) + seconds(usage.ru_stime)
  }

  /// Physical footprint in bytes (Activity Monitor's Memory column).
  static func memory() -> UInt64 {
    var info = rusage_info_v4()
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
        proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
      }
    }
    return result == 0 ? info.ri_phys_footprint : 0
  }
}

/// Samples every two seconds while it is on screen.
struct ResourceUsageLabel: View {
  @State private var cpu: Double?
  @State private var memory: UInt64 = ResourceUsage.memory()

  var body: some View {
    Group {
      if let cpu {
        Text(
          "CPU \((cpu / 100).formatted(.percent.precision(.fractionLength(1)))) · Memory \(Int64(memory).formatted(.byteCount(style: .memory)))",
          comment: "The app's own resource use")
      } else {
        Text(
          "Memory \(Int64(memory).formatted(.byteCount(style: .memory)))",
          comment: "The app's own memory use")
      }
    }
    .monospacedDigit()
    .foregroundStyle(.secondary)
    .task {
      var lastTime = ResourceUsage.cpuTime()
      var lastDate = Date.now
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(2))
        } catch {
          return
        }
        let time = ResourceUsage.cpuTime()
        let elapsed = Date.now.timeIntervalSince(lastDate)
        if elapsed > 0 {
          cpu = max(0, (time - lastTime) / elapsed * 100)
        }
        memory = ResourceUsage.memory()
        lastTime = time
        lastDate = .now
      }
    }
  }
}
