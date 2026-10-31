import os

/// One logger per module. Stream them with:
/// `log stream --predicate 'subsystem == "io.github.muazfurkan.ljaspnotch"' --level debug`
enum Log {
  static let subsystem = "io.github.muazfurkan.ljaspnotch"

  static let app = Logger(subsystem: subsystem, category: "App")
  static let settings = Logger(subsystem: subsystem, category: "Settings")
}
