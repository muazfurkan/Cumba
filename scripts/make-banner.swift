import AppKit

// Draws the README banner and GitHub social preview (1280 × 640 px): the open notch panel
// with a mini player hanging from the top edge, and the app icon and name below it.
//
//   xcrun swift scripts/make-banner.swift docs/icon.png docs/banner.png
guard CommandLine.arguments.count == 3 else {
  print("usage: make-banner.swift <icon.png> <out.png>")
  exit(1)
}
let width: CGFloat = 1280
let height: CGFloat = 640

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let gold = color(0xDCB669)

guard
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0),
  let base = NSGraphicsContext(bitmapImageRep: rep),
  let icon = NSImage(contentsOfFile: CommandLine.arguments[1])
else { fatalError("Could not set up drawing") }

// Top-left origin, like the screen the panel hangs from.
let cg = base.cgContext
cg.translateBy(x: 0, y: height)
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

// Background: deep navy with a warm glow behind the panel.
NSGradient(colors: [color(0x0E1729), color(0x05070C)])?
  .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)
NSGradient(colors: [gold.withAlphaComponent(0.16), gold.withAlphaComponent(0)])?
  .draw(
    fromCenter: NSPoint(x: width / 2, y: 140), radius: 0,
    toCenter: NSPoint(x: width / 2, y: 140), radius: 560, options: [])

// The panel: notch flares at the top, round corners at the bottom.
let panel = NSRect(x: 330, y: 0, width: 620, height: 232)
let flare: CGFloat = 18
let corner: CGFloat = 44
let k: CGFloat = 0.45
let shape = NSBezierPath()
shape.move(to: NSPoint(x: panel.minX - flare, y: 0))
shape.curve(
  to: NSPoint(x: panel.minX, y: flare), controlPoint1: NSPoint(x: panel.minX - flare * k, y: 0),
  controlPoint2: NSPoint(x: panel.minX, y: flare * k))
shape.line(to: NSPoint(x: panel.minX, y: panel.maxY - corner))
shape.curve(
  to: NSPoint(x: panel.minX + corner, y: panel.maxY),
  controlPoint1: NSPoint(x: panel.minX, y: panel.maxY - corner * k),
  controlPoint2: NSPoint(x: panel.minX + corner * k, y: panel.maxY))
shape.line(to: NSPoint(x: panel.maxX - corner, y: panel.maxY))
shape.curve(
  to: NSPoint(x: panel.maxX, y: panel.maxY - corner),
  controlPoint1: NSPoint(x: panel.maxX - corner * k, y: panel.maxY),
  controlPoint2: NSPoint(x: panel.maxX, y: panel.maxY - corner * k))
shape.line(to: NSPoint(x: panel.maxX, y: flare))
shape.curve(
  to: NSPoint(x: panel.maxX + flare, y: 0), controlPoint1: NSPoint(x: panel.maxX, y: flare * k),
  controlPoint2: NSPoint(x: panel.maxX + flare * k, y: 0))
shape.close()

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: NSColor.black.cgColor)
NSColor.black.setFill()
shape.fill()
cg.restoreGState()
NSColor.white.withAlphaComponent(0.08).setStroke()
shape.lineWidth = 1.5
shape.stroke()

func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSImage? {
  NSImage(systemSymbolName: name, accessibilityDescription: nil)?
    .withSymbolConfiguration(
      .init(pointSize: size, weight: weight)
        .applying(.init(paletteColors: [.white])))
}

func draw(_ image: NSImage?, centeredAt point: NSPoint, alpha: CGFloat = 1) {
  guard let image else { return }
  let rect = NSRect(
    x: point.x - image.size.width / 2, y: point.y - image.size.height / 2,
    width: image.size.width, height: image.size.height)
  image.draw(
    in: rect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true,
    hints: nil)
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1)
  -> NSAttributedString
{
  NSAttributedString(
    string: string,
    attributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: NSColor.white.withAlphaComponent(alpha),
      .kern: size > 40 ? -1.2 : 0,
    ])
}

// Tab bar, below the camera housing.
let tabs = ["music.note", "terminal", "calendar", "timer", "battery.75percent", "cloud.sun"]
for (index, name) in tabs.enumerated() {
  let center = NSPoint(x: panel.minX + 52 + CGFloat(index) * 50, y: 62)
  if index == 0 {
    NSColor.white.withAlphaComponent(0.14).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: center.x - 21, y: center.y - 16, width: 42, height: 32),
      xRadius: 16, yRadius: 16
    ).fill()
  }
  draw(symbol(name, size: 17, weight: .medium), centeredAt: center, alpha: index == 0 ? 1 : 0.5)
}
draw(
  symbol("gearshape", size: 17, weight: .medium), centeredAt: NSPoint(x: panel.maxX - 48, y: 62),
  alpha: 0.5)

// Mini player: artwork, title, controls and progress.
let art = NSRect(x: panel.minX + 32, y: 96, width: 100, height: 100)
cg.saveGState()
cg.setShadow(
  offset: CGSize(width: 0, height: -6), blur: 30, color: gold.withAlphaComponent(0.55).cgColor)
let artPath = NSBezierPath(roundedRect: art, xRadius: 18, yRadius: 18)
color(0xDCB669).setFill()
artPath.fill()
cg.restoreGState()
cg.saveGState()
artPath.addClip()
NSGradient(colors: [color(0xF2D08A), color(0xE07A5F), color(0x6B3FA0)])?.draw(in: art, angle: -60)
NSColor.white.withAlphaComponent(0.18).setFill()
NSBezierPath(ovalIn: NSRect(x: art.minX + 44, y: art.minY - 20, width: 90, height: 90)).fill()
NSColor.black.withAlphaComponent(0.12).setFill()
NSBezierPath(ovalIn: NSRect(x: art.minX - 30, y: art.minY + 52, width: 80, height: 80)).fill()
cg.restoreGState()

text("Night Signals", size: 26, weight: .semibold).draw(at: NSPoint(x: art.maxX + 24, y: 104))
text("Studio Session", size: 20, weight: .regular, alpha: 0.55)
  .draw(at: NSPoint(x: art.maxX + 24, y: 140))

let controlsY: CGFloat = 126
draw(
  symbol("backward.fill", size: 22), centeredAt: NSPoint(x: panel.maxX - 166, y: controlsY),
  alpha: 0.85)
draw(symbol("pause.fill", size: 32), centeredAt: NSPoint(x: panel.maxX - 108, y: controlsY))
draw(
  symbol("forward.fill", size: 22), centeredAt: NSPoint(x: panel.maxX - 50, y: controlsY),
  alpha: 0.85)

let track = NSRect(x: art.maxX + 24, y: 184, width: panel.maxX - 32 - art.maxX - 24, height: 6)
NSColor.white.withAlphaComponent(0.18).setFill()
NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
NSColor.white.setFill()
NSBezierPath(
  roundedRect: NSRect(x: track.minX, y: track.minY, width: track.width * 0.38, height: 6),
  xRadius: 3, yRadius: 3
).fill()

// Icon and name.
let title = text("ljaspNotch", size: 84, weight: .bold)
let tagline = text("Your MacBook notch, made useful.", size: 28, weight: .medium, alpha: 0.7)
let iconSize: CGFloat = 116
let gap: CGFloat = 30
let textWidth = max(title.size().width, tagline.size().width)
let groupX = (width - iconSize - gap - textWidth) / 2
let groupY: CGFloat = 320
icon.draw(
  in: NSRect(x: groupX, y: groupY + 6, width: iconSize, height: iconSize), from: .zero,
  operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
title.draw(at: NSPoint(x: groupX + iconSize + gap, y: groupY - 12))
tagline.draw(at: NSPoint(x: groupX + iconSize + gap + 3, y: groupY + 100))

let footer = text(
  "Free and open source  ·  Media  ·  Claude Code  ·  Widgets  ·  Themes", size: 22,
  weight: .medium, alpha: 0.42)
footer.draw(at: NSPoint(x: (width - footer.size().width) / 2, y: 540))

NSGraphicsContext.current = nil
guard let data = rep.representation(using: .png, properties: [:]) else {
  fatalError("Could not encode the banner")
}
do {
  try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
} catch {
  fatalError("Could not write the banner: \(error)")
}
