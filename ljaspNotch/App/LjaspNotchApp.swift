import AppKit

/// Entry point. The app uses the AppKit lifecycle because it lives in the menu bar
/// and manages its own windows.
@main
@MainActor
enum LjaspNotchApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) {
      app.run()
    }
  }
}
