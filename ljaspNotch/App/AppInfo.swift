import Foundation

/// Version info from Info.plist, which gets it from MARKETING_VERSION and
/// CURRENT_PROJECT_VERSION in project.yml.
enum AppInfo {
  static var version: String { string(for: "CFBundleShortVersionString") }
  static var build: String { string(for: "CFBundleVersion") }

  private static func string(for key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "-"
  }
}
