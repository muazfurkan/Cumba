import AppKit
import CoreImage
import SwiftUI

/// Loads and decodes artwork once per track, off the main thread, and finds its average
/// color for the media card's glow. Remote artwork is fetched with an ephemeral session
/// (no cookies, memory-only cache) and only over https.
@MainActor
final class ArtworkCache {
  struct Entry {
    let image: NSImage
    let color: Color?
  }

  static let shared = ArtworkCache()

  private let cache = NSCache<NSString, Box>()
  private let session: URLSession

  private final class Box {
    let entry: Entry
    init(_ entry: Entry) { self.entry = entry }
  }

  init() {
    cache.countLimit = 12
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.httpCookieStorage = nil
    session = URLSession(configuration: configuration)
  }

  static func key(for nowPlaying: NowPlaying) -> String? {
    if let data = nowPlaying.artworkData {
      return "data-\(data.count)-\(data.hashValue)"
    }
    return nowPlaying.artworkURL?.absoluteString
  }

  func cached(for nowPlaying: NowPlaying) -> Entry? {
    Self.key(for: nowPlaying).flatMap { cache.object(forKey: $0 as NSString)?.entry }
  }

  func load(for nowPlaying: NowPlaying) async -> Entry? {
    guard let key = Self.key(for: nowPlaying) else { return nil }
    if let entry = cache.object(forKey: key as NSString)?.entry {
      return entry
    }
    var data = nowPlaying.artworkData
    if data == nil, let url = nowPlaying.artworkURL, url.scheme == "https" {
      data = try? await session.data(from: url).0
    }
    guard let data, data.count < 8_000_000 else { return nil }
    let decoded = await Task.detached { () -> (NSImage, HexColor?)? in
      guard let image = NSImage(data: data) else { return nil }
      return (image, Self.averageColor(of: data))
    }.value
    guard let decoded else { return nil }
    let entry = Entry(image: decoded.0, color: decoded.1?.color)
    cache.setObject(Box(entry), forKey: key as NSString)
    return entry
  }

  /// Average color of an image, lifted a little so it reads as a glow on black.
  nonisolated static func averageColor(of data: Data) -> HexColor? {
    guard let input = CIImage(data: data),
      let filter = CIFilter(
        name: "CIAreaAverage",
        parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]),
      let output = filter.outputImage
    else { return nil }
    var pixel = [UInt8](repeating: 0, count: 4)
    CIContext(options: [.workingColorSpace: NSNull()]).render(
      output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8, colorSpace: nil)
    func lift(_ value: UInt8) -> UInt8 {
      UInt8(min(255, Double(value) * 1.25 + 20))
    }
    return HexColor(red: lift(pixel[0]), green: lift(pixel[1]), blue: lift(pixel[2]))
  }
}
