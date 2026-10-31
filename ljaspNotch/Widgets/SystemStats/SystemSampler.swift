import Darwin
import Foundation

/// Reads CPU and memory load with Mach host statistics. Pure math is separated so it can be
/// unit tested.
enum SystemSampler {
  /// Cumulative CPU ticks since boot.
  struct CPUTicks: Equatable, Sendable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }
  }

  struct Memory: Equatable, Sendable {
    var used: UInt64
    var total: UInt64
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
  }

  /// Share of time the CPU was busy between two readings, 0...1.
  static func cpuLoad(from old: CPUTicks, to new: CPUTicks) -> Double {
    guard new.total > old.total, new.busy >= old.busy else { return 0 }
    let busy = Double(new.busy - old.busy)
    let total = Double(new.total - old.total)
    return min(1, max(0, busy / total))
  }

  static func readCPUTicks() -> CPUTicks? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return CPUTicks(
      user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
      idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
  }

  /// Used memory the way Activity Monitor counts it: app memory, wired and compressed.
  static func readMemory() -> Memory? {
    var stats = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &stats) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    let pageSize = UInt64(max(sysconf(_SC_PAGESIZE), 4096))
    let appPages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
    let used =
      (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize
    return Memory(used: used, total: ProcessInfo.processInfo.physicalMemory)
  }
}
