import SwiftUI

/// "hello" written in one connected stroke, drawn for Cumba. A smooth curve runs through the
/// points a pen passes; trimming it from 0 to 1 writes the word.
struct HelloShape: Shape {
  /// The design's own coordinate space (y down); the path is scaled to fit its rect.
  static let designSize = CGSize(width: 360, height: 180)

  /// A cubic curve in design coordinates.
  struct Curve: Equatable {
    var from, c1, c2, to: CGPoint

    func point(at t: CGFloat) -> CGPoint {
      let u = 1 - t
      let a = u * u * u
      let b = 3 * u * u * t
      let c = 3 * u * t * t
      let d = t * t * t
      return CGPoint(
        x: a * from.x + b * c1.x + c * c2.x + d * to.x,
        y: a * from.y + b * c1.y + c * c2.y + d * to.y)
    }
  }

  /// Points the pen passes through. Each run is one smooth curve; the next run starts where
  /// it ends, and the pen turns sharply there (at the foot of the h).
  private static let runs: [[(CGFloat, CGFloat)]] = [
    // Lead-in, the h's loop and its stem.
    [
      (18, 150), (42, 141), (66, 120), (85, 92), (97, 62), (100, 40), (94, 27), (85, 24),
      (77, 31), (72, 50), (67, 82), (62, 117), (58, 151),
    ],
    // The h's arch, then e, l, l and o.
    [
      (58, 151), (61, 132), (68, 117), (79, 107), (91, 105), (99, 112), (102, 127),
      (104, 142), (110, 151), (121, 152), (133, 146),
      // e
      (149, 136), (162, 124), (168, 113), (165, 104), (155, 102), (146, 109), (143, 124),
      (147, 140), (157, 150), (171, 151), (184, 145),
      // l
      (198, 129), (212, 105), (222, 78), (227, 53), (225, 34), (217, 25), (207, 27), (201, 42),
      (196, 74), (193, 108), (194, 133), (200, 148), (211, 152), (224, 146),
      // l
      (238, 128), (251, 102), (260, 74), (265, 50), (262, 33), (254, 25), (244, 28), (238, 44),
      (234, 76), (232, 110), (234, 134), (240, 148), (251, 152), (263, 146),
      // o: up its left side, over the top, around, up again and out with the tail.
      (270, 132), (276, 117), (285, 107), (296, 106), (304, 114), (306, 129), (302, 143),
      (292, 151), (281, 150), (274, 141), (273, 129), (278, 119), (288, 115), (298, 117),
      (308, 116), (321, 110), (336, 101),
    ],
  ]

  /// The whole word as cubic curves, in design coordinates.
  static let curves: [Curve] = runs.flatMap { run in
    smoothCurves(through: run.map { CGPoint(x: $0.0, y: $0.1) })
  }

  func path(in rect: CGRect) -> Path {
    let size = Self.designSize
    let scale = min(rect.width / size.width, rect.height / size.height)
    let origin = CGPoint(
      x: rect.midX - size.width * scale / 2, y: rect.midY - size.height * scale / 2)
    func place(_ point: CGPoint) -> CGPoint {
      CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }
    var path = Path()
    guard let first = Self.curves.first else { return path }
    path.move(to: place(first.from))
    for curve in Self.curves {
      path.addCurve(to: place(curve.to), control1: place(curve.c1), control2: place(curve.c2))
    }
    return path
  }

  /// How far along the word the pen is over time, like a hand writing it: slower in tight
  /// turns, with a short stop where it turns back. `values` are fractions of the word's
  /// length and `times` fractions of the writing time, both from 0 to 1.
  static func pace(stepsPerCurve: Int = 16) -> (values: [Double], times: [Double]) {
    let points = curves.flatMap { curve in
      (1...stepsPerCurve).map { curve.point(at: CGFloat($0) / CGFloat(stepsPerCurve)) }
    }
    guard let start = curves.first?.from else { return ([0, 1], [0, 1]) }
    var length = [0.0]
    var time = [0.0]
    var previous = start
    var heading: Double?
    for point in [start] + points where point != previous {
      let dx = Double(point.x - previous.x)
      let dy = Double(point.y - previous.y)
      let step = (dx * dx + dy * dy).squareRoot()
      let direction = atan2(dy, dx)
      // Each radian the pen turns costs as long as drawing this many points of line.
      var turn = 0.0
      if let heading {
        turn = abs(remainder(direction - heading, 2 * .pi))
      }
      length.append(length[length.count - 1] + step)
      time.append(time[time.count - 1] + step + turn * 9)
      heading = direction
      previous = point
    }
    guard let totalLength = length.last, let totalTime = time.last, totalLength > 0 else {
      return ([0, 1], [0, 1])
    }
    return (length.map { $0 / totalLength }, time.map { $0 / totalTime })
  }

  /// Bézier curves through the points, without overshooting between them (centripetal
  /// Catmull-Rom). The ends continue in the direction of their neighbors.
  private static func smoothCurves(through points: [CGPoint]) -> [Curve] {
    guard points.count > 1, let first = points.first, let last = points.last else { return [] }
    func reflect(_ point: CGPoint, over center: CGPoint) -> CGPoint {
      CGPoint(x: 2 * center.x - point.x, y: 2 * center.y - point.y)
    }
    let padded =
      [reflect(points[1], over: first)] + points + [reflect(points[points.count - 2], over: last)]
    return (1..<padded.count - 2).map { index in
      let p0 = padded[index - 1]
      let p1 = padded[index]
      let p2 = padded[index + 1]
      let p3 = padded[index + 2]
      let d1 = p0.distance(to: p1)
      let d2 = p1.distance(to: p2)
      let d3 = p2.distance(to: p3)
      let (s1, s2, s3) = (d1.squareRoot(), d2.squareRoot(), d3.squareRoot())
      func blend(_ weights: (CGFloat, CGFloat, CGFloat), _ a: CGPoint, _ b: CGPoint, _ c: CGPoint)
        -> CGPoint
      {
        let sum = weights.0 + weights.1 + weights.2
        return CGPoint(
          x: (weights.0 * a.x + weights.1 * b.x + weights.2 * c.x) / sum,
          y: (weights.0 * a.y + weights.1 * b.y + weights.2 * c.y) / sum)
      }
      let c1 =
        s1 > 0 ? blend((d1, -d2, 2 * d1 + 3 * s1 * s2 + d2), p2, p0, p1) : p1
      let c2 =
        s3 > 0 ? blend((d3, -d2, 2 * d3 + 3 * s3 * s2 + d2), p1, p3, p2) : p2
      return Curve(from: p1, c1: c1, c2: c2, to: p2)
    }
  }
}

extension CGPoint {
  fileprivate func distance(to other: CGPoint) -> CGFloat {
    hypot(other.x - x, other.y - y)
  }
}
