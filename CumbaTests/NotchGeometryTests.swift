import CoreGraphics
import Testing

@testable import Cumba

struct NotchGeometryTests {
  // Roughly a 14-inch MacBook Pro at its default resolution.
  private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

  private func geometry(screen: CGRect? = nil) throws -> NotchGeometry {
    try #require(
      NotchGeometry(
        screenFrame: screen ?? self.screen, safeAreaTop: 32, leftAreaWidth: 662,
        rightAreaWidth: 662))
  }

  @Test func screenWithoutNotchHasNoGeometry() {
    let geometry = NotchGeometry(
      screenFrame: screen, safeAreaTop: 0, leftAreaWidth: 0, rightAreaWidth: 0)
    #expect(geometry == nil)
  }

  @Test func notchSitsAtTopBetweenAuxiliaryAreas() throws {
    #expect(try geometry().notchRect == CGRect(x: 662, y: 950, width: 188, height: 32))
  }

  @Test func panelWidthNarrowsTheShapeButNotTheWindow() throws {
    var layout = NotchLayout()
    layout.panelWidth = 420
    let narrow = try #require(
      NotchGeometry(
        screenFrame: screen, safeAreaTop: 32, leftAreaWidth: 662, rightAreaWidth: 662,
        layout: layout))
    #expect(narrow.shapeSize(for: .expanded).width == 420)
    #expect(narrow.windowFrame == (try geometry().windowFrame))
    layout.panelWidth = 5000
    let wide = try #require(
      NotchGeometry(
        screenFrame: screen, safeAreaTop: 32, leftAreaWidth: 662, rightAreaWidth: 662,
        layout: layout))
    #expect(wide.shapeSize(for: .expanded).width == 640)
  }

  @Test func windowIsCenteredUnderNotchAndTopAligned() throws {
    let frame = try geometry().windowFrame
    // 640 + 2 × 24 shadow margin wide, 190 + 24 tall.
    #expect(frame == CGRect(x: 412, y: 768, width: 688, height: 214))
  }

  @Test(arguments: NotchState.allCases)
  func everyShapeFitsInTheWindow(state: NotchState) throws {
    let geometry = try geometry()
    #expect(geometry.windowFrame.contains(geometry.shapeRect(for: state)))
  }

  @Test(arguments: NotchState.allCases)
  func everyShapeHangsFromTheNotch(state: NotchState) throws {
    let geometry = try geometry()
    let rect = geometry.shapeRect(for: state)
    #expect(rect.maxY == screen.maxY)
    #expect(rect.midX == geometry.notchRect.midX)
  }

  @Test func closedShapeReachesALittlePastTheNotch() throws {
    let geometry = try geometry()
    let closed = geometry.shapeRect(for: .closed)
    let growth = geometry.layout.closedGrowth
    #expect(growth == CGSize(width: 8, height: 5))
    #expect(closed.contains(geometry.notchRect))
    #expect(closed.width == geometry.notchRect.width + growth.width * 2)
    #expect(closed.minY == geometry.notchRect.minY - growth.height)
  }

  @Test func closedSizeComesFromThePanelSize() throws {
    var size = PanelSize()
    size.closedWidth = 0
    size.closedHeight = 12
    let geometry = try #require(
      NotchGeometry(
        screenFrame: screen, safeAreaTop: 32, leftAreaWidth: 662, rightAreaWidth: 662,
        layout: NotchLayout(size: size)))
    #expect(geometry.shapeSize(for: .closed) == CGSize(width: 188, height: 44))
  }

  @Test func peekAddsWidthOnBothSidesAndARowBelowTheNotch() throws {
    #expect(
      try geometry().shapeSize(for: .peek)
        == CGSize(width: 188 + 140, height: 32 + NotchLayout.peekExtraHeight))
  }

  @Test func hoverAreaIncludesTheTopEdge() throws {
    let geometry = try geometry()
    let topCenter = CGPoint(x: geometry.notchRect.midX, y: screen.maxY)
    #expect(geometry.hoverRect(for: .closed).contains(topCenter))
    #expect(geometry.hoverRect(for: .expanded).contains(topCenter))
  }

  @Test func screenOffsetIsRespected() throws {
    let external = CGRect(x: -1512, y: 300, width: 1512, height: 982)
    let notch = try geometry(screen: external).notchRect
    let expectedMinX: CGFloat = -1512 + 662
    let expectedMaxY: CGFloat = 300 + 982
    #expect(notch.minX == expectedMinX)
    #expect(notch.maxY == expectedMaxY)
  }

  @Test func virtualNotchSitsInTheMiddleOfTheMenuBar() {
    let geometry = NotchGeometry(virtualOn: screen, menuBarHeight: 24, width: 200)
    #expect(geometry.isVirtual)
    #expect(geometry.notchRect == CGRect(x: 656, y: 958, width: 200, height: 24))
    #expect(geometry.shapeRect(for: .expanded).maxY == screen.maxY)
  }

  @Test func layoutFollowsThePanelSize() {
    var size = PanelSize()
    size.width = 800
    size.height = 300
    size.indicatorWidth = 40
    let layout = NotchLayout(size: size)
    #expect(layout.expandedSize == CGSize(width: 800, height: 300))
    #expect(layout.peekExtraWidth == 40)
  }
}
