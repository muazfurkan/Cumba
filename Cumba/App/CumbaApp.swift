import AppKit

/// Entry point. The app uses the AppKit lifecycle because it lives in the menu bar
/// and manages its own windows.
@main
@MainActor
enum CumbaApp {
  static func main() {
    // Before anything reads the folder, and before any window exists: a rename on the
    // same volume is one quick metadata call, so it can't make the UI hang.
    AppFolder.migrateLegacyFolder()
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) {
      app.run()
    }
  }
}
