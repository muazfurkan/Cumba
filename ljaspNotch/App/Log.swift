import os

/// One logger per module. Stream them with:
/// `log stream --predicate 'subsystem == "io.github.muazfurkan.ljaspnotch"' --level debug`
enum Log {
  static let subsystem = "io.github.muazfurkan.ljaspnotch"

  static let app = Logger(subsystem: subsystem, category: "App")
  static let media = Logger(subsystem: subsystem, category: "Media")
  static let notch = Logger(subsystem: subsystem, category: "Notch")
  static let server = Logger(subsystem: subsystem, category: "Server")
  static let settings = Logger(subsystem: subsystem, category: "Settings")
  static let theme = Logger(subsystem: subsystem, category: "Theme")
  static let widgets = Logger(subsystem: subsystem, category: "Widgets")
}
