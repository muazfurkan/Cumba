import Foundation

/// Version info from Info.plist, which gets it from MARKETING_VERSION and
/// CURRENT_PROJECT_VERSION in project.yml.
enum AppInfo {
  static var version: String { string(for: "CFBundleShortVersionString") }
  static var build: String { string(for: "CFBundleVersion") }

  /// True when the app runs from /Applications or ~/Applications. Run from Downloads, a
  /// downloaded app is moved by macOS to a random read-only path (App Translocation).
  static func isInApplicationsFolder(
    _ bundleURL: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> Bool {
    let path = bundleURL.standardizedFileURL.path
    let folders = ["/Applications/", home.appending(path: "Applications").path + "/"]
    return folders.contains { path.hasPrefix($0) }
  }

  private static func string(for key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "-"
  }
}
