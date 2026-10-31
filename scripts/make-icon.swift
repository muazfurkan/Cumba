import AppKit

// Draws the "L | J" mark from simple shapes (no font glyphs) and writes the app icon
// master (icon_1024.png) and the menu bar template images (menubar.png, menubar@2x.png).
//
//   xcrun swift scripts/make-icon.swift <out-dir>
//
// Then resize icon_1024.png into AppIcon.appiconset (e.g. with `sips -z`) and copy the
// menu bar images into MenuBarIcon.imageset.
guard CommandLine.arguments.count == 2 else {
  print("usage: make-icon.swift <out-dir>")
  exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
let navy = NSColor(srgbRed: 10 / 255, green: 22 / 255, blue: 40 / 255, alpha: 1)
let gold = NSColor(srgbRed: 0xDC / 255, green: 0xB6 / 255, blue: 0x69 / 255, alpha: 1)

func bitmap(_ size: Int) -> NSBitmapImageRep {
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)
  else { fatalError("Could not create a \(size) px bitmap") }
  return rep
}

func write(_ rep: NSBitmapImageRep, _ name: String) {
  guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode \(name)")
  }
  do {
    try data.write(to: outDir.appendingPathComponent(name))
  } catch {
    fatalError("Could not write \(name): \(error)")
  }
}

/// The mark in a 440 × 440 design box (origin bottom left), scaled into `rect`.
func drawMark(in rect: NSRect, color: NSColor, stroke: CGFloat = 64, bar: CGFloat = 14) {
  let s = rect.width / 440
  func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: rect.minX + x * s, y: rect.minY + y * s, width: w * s, height: h * s)
  }
  color.setFill()
  color.setStroke()
  // L: stem and foot.
  NSBezierPath(rect: r(0, 0, stroke, 440)).fill()
  NSBezierPath(rect: r(0, 0, 170, stroke)).fill()
  // Divider.
  NSBezierPath(rect: r(220 - bar / 2, 0, bar, 440)).fill()
  // J: top bar, stem and a round hook, drawn as one stroked center line.
  NSBezierPath(rect: r(300, 440 - stroke, 140, stroke)).fill()
  let half = stroke / 2
  let stemX = 440 - half
  let radius: CGFloat = 54
  let hookY = half + radius
  let j = NSBezierPath()
  j.move(to: NSPoint(x: rect.minX + stemX * s, y: rect.minY + (440 - stroke) * s))
  j.line(to: NSPoint(x: rect.minX + stemX * s, y: rect.minY + hookY * s))
  j.appendArc(
    withCenter: NSPoint(x: rect.minX + (stemX - radius) * s, y: rect.minY + hookY * s),
    radius: radius * s, startAngle: 0, endAngle: 180, clockwise: true)
  j.line(to: NSPoint(x: rect.minX + (stemX - 2 * radius) * s, y: rect.minY + (hookY + 30) * s))
  j.lineWidth = stroke * s
  j.lineCapStyle = .butt
  j.stroke()
}

/// Superellipse ("squircle") like the macOS icon grid.
func squircle(in rect: NSRect, exponent: CGFloat = 5) -> NSBezierPath {
  let path = NSBezierPath()
  let a = rect.width / 2, b = rect.height / 2
  for i in 0...720 {
    let t = CGFloat(i) / 720 * 2 * .pi
    let c = cos(t), s = sin(t)
    let p = NSPoint(
      x: rect.midX + a * copysign(pow(abs(c), 2 / exponent), c),
      y: rect.midY + b * copysign(pow(abs(s), 2 / exponent), s))
    i == 0 ? path.move(to: p) : path.line(to: p)
  }
  path.close()
  return path
}

// App icon, 1024 px on Apple's grid: 824 px body with a 100 px margin.
let master = bitmap(1024)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: master)
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = squircle(in: body)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
NSGraphicsContext.saveGraphicsState()
shadow.set()
navy.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])?
  .draw(in: body, angle: -90)
NSGraphicsContext.restoreGraphicsState()
drawMark(in: NSRect(x: 512 - 220, y: 512 - 220, width: 440, height: 440), color: gold)
NSGraphicsContext.restoreGraphicsState()
write(master, "icon_1024.png")

// Menu bar template: black mark, 15 pt tall in an 18 pt square, with a thicker divider
// so it stays visible at this size.
for scale in [1, 2] {
  let size = 18 * scale
  let rep = bitmap(size)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let side = CGFloat(15 * scale)
  let origin = (CGFloat(size) - side) / 2
  drawMark(
    in: NSRect(x: origin, y: origin, width: side, height: side), color: .black, stroke: 72,
    bar: 40)
  NSGraphicsContext.restoreGraphicsState()
  write(rep, scale == 1 ? "menubar.png" : "menubar@2x.png")
}
