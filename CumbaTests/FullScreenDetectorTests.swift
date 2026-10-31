import CoreGraphics
import Testing

@testable import Cumba

/// Window layouts recorded on a 14-inch MacBook Pro (1800 × 1169 points, 39-point notch).
struct FullScreenDetectorTests {
  private typealias Window = FullScreenDetector.Window

  private let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
  private let menuBar = Window(
    ownerPID: 1, layer: 24, bounds: CGRect(x: 0, y: 0, width: 1800, height: 39))

  private func isFullScreen(_ windows: [Window]) -> Bool {
    FullScreenDetector.isFullScreen(windows: windows, screen: screen, notchHeight: 39)
  }

  @Test func normalDesktopIsNotFullScreen() {
    let app = Window(
      ownerPID: 42, layer: 0, bounds: CGRect(x: 200, y: 200, width: 400, height: 332))
    #expect(!isFullScreen([menuBar, app]))
  }

  @Test func fullScreenAppBelowTheNotchIsDetected() {
    let content = Window(
      ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 39, width: 1800, height: 1130))
    let strip = Window(ownerPID: 42, layer: 26, bounds: CGRect(x: 0, y: 0, width: 1800, height: 39))
    #expect(isFullScreen([menuBar, strip, content]))
  }

  @Test func zoomedWindowWithoutStripIsNotFullScreen() {
    // Same rect as a full screen window when the Dock hides itself.
    let zoomed = Window(
      ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 39, width: 1800, height: 1130))
    #expect(!isFullScreen([menuBar, zoomed]))
  }

  @Test func stripOfAnotherAppDoesNotCount() {
    let zoomed = Window(
      ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 39, width: 1800, height: 1130))
    let strip = Window(ownerPID: 7, layer: 26, bounds: CGRect(x: 0, y: 0, width: 1800, height: 39))
    #expect(!isFullScreen([zoomed, strip]))
  }

  @Test func windowCoveringTheWholeScreenIsFullScreen() {
    let game = Window(ownerPID: 42, layer: 0, bounds: screen)
    #expect(isFullScreen([menuBar, game]))
  }

  @Test func fullScreenOnAnotherDisplayIsIgnored() {
    let external = CGRect(x: 1800, y: -200, width: 2560, height: 1440)
    let content = Window(ownerPID: 42, layer: 0, bounds: external)
    #expect(!isFullScreen([menuBar, content]))
  }
}
