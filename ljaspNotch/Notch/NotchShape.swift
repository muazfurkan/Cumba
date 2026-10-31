import SwiftUI

/// Outline of the panel: hangs from the top edge, flares outward where it meets the edge
/// and has rounded bottom corners, like the hardware notch.
struct NotchShape: Shape {
  var topRadius: CGFloat
  var bottomRadius: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(topRadius, bottomRadius) }
    set {
      topRadius = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let top = max(0, min(topRadius, rect.width / 4, rect.height / 2))
    let bottom = max(0, min(bottomRadius, rect.width / 2 - top, rect.height - top))
    let left = rect.minX + top
    let right = rect.maxX - top

    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addQuadCurve(
      to: CGPoint(x: left, y: rect.minY + top), control: CGPoint(x: left, y: rect.minY))
    path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
    path.addQuadCurve(
      to: CGPoint(x: left + bottom, y: rect.maxY), control: CGPoint(x: left, y: rect.maxY))
    path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
    path.addQuadCurve(
      to: CGPoint(x: right, y: rect.maxY - bottom), control: CGPoint(x: right, y: rect.maxY))
    path.addLine(to: CGPoint(x: right, y: rect.minY + top))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
    path.closeSubpath()
    return path
  }
}
