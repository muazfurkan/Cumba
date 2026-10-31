import CoreGraphics
import Foundation

/// Detects a full screen app on the notched screen from the window list. It reads only
/// window bounds, layers and owner PIDs, which need no screen recording permission.
enum FullScreenDetector {
  struct Window: Equatable, Sendable {
    var ownerPID: pid_t
    var layer: Int
    /// Core Graphics coordinates (origin at the top left).
    var bounds: CGRect
  }

  /// - Parameters:
  ///   - screen: The notched screen in Core Graphics coordinates.
  ///   - notchHeight: Height of the strip beside the camera housing.
  static func isFullScreen(windows: [Window], screen: CGRect, notchHeight: CGFloat) -> Bool {
    let tolerance: CGFloat = 1

    func spansWidth(_ rect: CGRect) -> Bool {
      rect.minX <= screen.minX + tolerance && rect.maxX >= screen.maxX - tolerance
    }

    for window in windows where window.layer == 0 {
      let bounds = window.bounds
      guard spansWidth(bounds), bounds.maxY >= screen.maxY - tolerance else { continue }
      // Covers the whole screen, including the strip beside the notch.
      if bounds.minY <= screen.minY + tolerance {
        return true
      }
      // On notched screens a full screen window starts below the notch, and its app owns a
      // second window that blacks out the strip above it. A zoomed window has no such strip.
      guard bounds.minY <= screen.minY + notchHeight + tolerance else { continue }
      let ownsTopStrip = windows.contains { other in
        other.ownerPID == window.ownerPID && other.layer > 0 && spansWidth(other.bounds)
          && other.bounds.minY <= screen.minY + tolerance
          && other.bounds.height <= notchHeight + tolerance
      }
      if ownsTopStrip {
        return true
      }
    }
    return false
  }

  /// On-screen windows of every app except the one with `excludedPID`.
  static func currentWindows(excluding excludedPID: pid_t) -> [Window] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard
      let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
    else { return [] }
    return list.compactMap { info in
      guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != excludedPID,
        let layer = info[kCGWindowLayer as String] as? Int,
        let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
        let bounds = CGRect(dictionaryRepresentation: boundsInfo)
      else { return nil }
      return Window(ownerPID: pid, layer: layer, bounds: bounds)
    }
  }
}
