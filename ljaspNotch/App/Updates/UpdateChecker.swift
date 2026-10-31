import Foundation
import Observation

/// Asks GitHub Releases for a newer version at launch and once a day. It only
/// reports; downloading and installing stay with the user. Can be turned off in Settings.
@MainActor
@Observable
final class UpdateChecker {
  struct Release: Equatable, Sendable {
    let version: String
    let url: URL
    let isPrerelease: Bool
  }

  private(set) var available: Release?
  private(set) var lastChecked: Date?
  private(set) var lastCheckFailed = false

  @ObservationIgnored private let settings: AppSettings
  @ObservationIgnored private var dailyTask: Task<Void, Never>?
  @ObservationIgnored private let session: URLSession

  private static let releasesURL = URL(
    string: "https://api.github.com/repos/muazfurkan/ljaspNotch/releases?per_page=20")

  init(settings: AppSettings) {
    self.settings = settings
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    session = URLSession(configuration: configuration)
  }

  /// Checks now and then every 24 hours while automatic checks are on.
  func start() {
    dailyTask?.cancel()
    guard settings.checksForUpdates else { return }
    dailyTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.checkNow()
        do {
          try await Task.sleep(for: .seconds(24 * 60 * 60))
        } catch {
          return
        }
      }
    }
  }

  func stop() {
    dailyTask?.cancel()
    dailyTask = nil
  }

  func checkNow() async {
    guard let url = Self.releasesURL else { return }
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("ljaspNotch/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
    do {
      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw URLError(.badServerResponse)
      }
      available = Self.newest(
        in: try Self.parse(data), than: AppInfo.version,
        includePrereleases: settings.includesPrereleases)
      lastCheckFailed = false
    } catch {
      lastCheckFailed = true
      Log.app.error("Update check failed: \(error.localizedDescription, privacy: .public)")
    }
    lastChecked = Date()
  }

  // MARK: - Pure helpers

  nonisolated static func parse(_ data: Data) throws -> [Release] {
    struct Item: Decodable {
      let tag: String
      let url: URL
      let prerelease: Bool
      let draft: Bool?

      enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case url = "html_url"
        case prerelease
        case draft
      }
    }
    return try JSONDecoder().decode([Item].self, from: data)
      .filter { $0.draft != true && $0.url.host() == "github.com" }
      .map {
        Release(
          version: $0.tag.hasPrefix("v") ? String($0.tag.dropFirst()) : $0.tag,
          url: $0.url, isPrerelease: $0.prerelease)
      }
  }

  nonisolated static func newest(
    in releases: [Release], than current: String, includePrereleases: Bool
  ) -> Release? {
    releases
      .filter { includePrereleases || !$0.isPrerelease }
      .filter { isVersion($0.version, newerThan: current) }
      .max { isVersion($1.version, newerThan: $0.version) }
  }

  /// Semantic version order: 1.2.0 > 1.1.9 and 1.0.0 > 1.0.0-rc1.
  nonisolated static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
    func parts(_ version: String) -> (numbers: [Int], prerelease: String?) {
      let pieces = version.split(separator: "-", maxSplits: 1).map(String.init)
      let numbers = pieces[0].split(separator: ".").map { Int($0) ?? 0 }
      return (numbers, pieces.count > 1 ? pieces[1] : nil)
    }
    let left = parts(lhs)
    let right = parts(rhs)
    for index in 0..<max(left.numbers.count, right.numbers.count) {
      let a = index < left.numbers.count ? left.numbers[index] : 0
      let b = index < right.numbers.count ? right.numbers[index] : 0
      if a != b {
        return a > b
      }
    }
    switch (left.prerelease, right.prerelease) {
    case (nil, .some): return true
    case (.some(let a), .some(let b)): return a.compare(b, options: .numeric) == .orderedDescending
    default: return false
    }
  }
}
