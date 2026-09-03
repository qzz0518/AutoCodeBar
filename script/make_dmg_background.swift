#!/usr/bin/env swift
import AppKit
import Foundation

// Draws the Finder backdrop for the disk image: a plain white sheet with a
// handful of small speech-bubble stickers scattered around the two big icons
// Finder itself draws. There is no source artwork on purpose — the picture is
// a few shapes, and generating it keeps a binary nobody can diff out of the
// repository.
//
// The canvas is 1520 x 1040 pixels presented as 760 x 520 points, so the image
// is a 2x asset and stays sharp on Retina displays.

private let arguments = CommandLine.arguments
guard arguments.count == 2 else {
  fputs("usage: make_dmg_background.swift <output.png>\n", stderr)
  exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let pointSize = NSSize(width: 760, height: 520)
let scale = 2

guard let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: Int(pointSize.width) * scale,
  pixelsHigh: Int(pointSize.height) * scale,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else {
  fputs("cannot create the disk image canvas\n", stderr)
  exit(1)
}

// The point size has to be declared before the drawing context is derived,
// otherwise the context maps one unit to one pixel and every coordinate below
// lands at half scale.
bitmap.size = pointSize

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
  fputs("cannot create the disk image drawing context\n", stderr)
  exit(1)
}

func color(_ hex: UInt32) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: 1
  )
}

/// Which corner of the bubble the cursor sits on.
enum Corner {
  case topLeft, topRight, bottomLeft, bottomRight

  /// Anchor for the cursor, offset from the bubble centre in the drawing space
  /// where y grows upward. It sits clear of the 42 x 32 bubble so the triangle
  /// reads as a separate mark rather than a notch cut out of the balloon.
  var anchor: NSPoint {
    switch self {
    case .topLeft: NSPoint(x: -28, y: 26)
    case .topRight: NSPoint(x: 28, y: 26)
    case .bottomLeft: NSPoint(x: -28, y: -26)
    case .bottomRight: NSPoint(x: 28, y: -26)
    }
  }
}

/// Where the cursor tip points, as an angle in the drawing space.
enum Heading {
  case down, upperLeft, upperRight

  var degrees: CGFloat {
    switch self {
    case .down: -90
    case .upperLeft: 135
    case .upperRight: 45
    }
  }
}

struct Sticker {
  let fill: NSColor
  /// Centre in points, measured from the top-left of the image.
  let center: NSPoint
  /// Positive tilts clockwise on screen.
  let rotation: CGFloat
  let corner: Corner
  let heading: Heading
}

let stickers = [
  Sticker(fill: color(0xF06E5A), center: NSPoint(x: 495, y: 70), rotation: -12,
          corner: .bottomRight, heading: .down),
  Sticker(fill: color(0xA9734A), center: NSPoint(x: 360, y: 140), rotation: 8,
          corner: .bottomRight, heading: .upperRight),
  Sticker(fill: color(0x0F9488), center: NSPoint(x: 680, y: 140), rotation: -15,
          corner: .bottomLeft, heading: .upperLeft),
  Sticker(fill: color(0x8B7BF2), center: NSPoint(x: 355, y: 370), rotation: 10,
          corner: .topRight, heading: .upperRight),
  Sticker(fill: color(0x4FA3F7), center: NSPoint(x: 680, y: 400), rotation: -8,
          corner: .topLeft, heading: .upperLeft),
  Sticker(fill: color(0xF2A93B), center: NSPoint(x: 470, y: 470), rotation: 6,
          corner: .topRight, heading: .upperRight)
]

/// The same closed outline as the app icon: a rounded speech bubble whose tail
/// grows out of the bottom-left corner rather than being pasted on, so a stroke
/// runs around the whole shape without a seam.
func bubblePath() -> NSBezierPath {
  let halfWidth: CGFloat = 21
  let halfHeight: CGFloat = 16
  let radius: CGFloat = 11
  let tailRadius: CGFloat = 6

  let path = NSBezierPath()
  path.move(to: NSPoint(x: halfWidth - radius, y: -halfHeight))
  path.appendArc(
    withCenter: NSPoint(x: halfWidth - radius, y: -halfHeight + radius),
    radius: radius, startAngle: -90, endAngle: 0
  )
  path.line(to: NSPoint(x: halfWidth, y: halfHeight - radius))
  path.appendArc(
    withCenter: NSPoint(x: halfWidth - radius, y: halfHeight - radius),
    radius: radius, startAngle: 0, endAngle: 90
  )
  path.line(to: NSPoint(x: -halfWidth + radius, y: halfHeight))
  path.appendArc(
    withCenter: NSPoint(x: -halfWidth + radius, y: halfHeight - radius),
    radius: radius, startAngle: 90, endAngle: 180
  )
  path.line(to: NSPoint(x: -halfWidth, y: -halfHeight + tailRadius))
  path.appendArc(
    withCenter: NSPoint(x: -halfWidth + tailRadius, y: -halfHeight + tailRadius),
    radius: tailRadius, startAngle: 180, endAngle: 270
  )
  path.line(to: NSPoint(x: -20, y: -26))
  path.line(to: NSPoint(x: -6, y: -halfHeight))
  path.close()
  return path
}

func cursorPath(corner: Corner, heading: Heading) -> NSBezierPath {
  let radians = heading.degrees * .pi / 180
  let side: CGFloat = 17
  // A 40-degree tip. At 60 degrees the triangle is equilateral and reads as a
  // plain shape with no direction at all.
  let spread: CGFloat = 160 * .pi / 180
  let anchor = corner.anchor
  // Nudge the tip forward from the anchor so the body of the triangle straddles
  // it and the whole mark stays balanced around the corner.
  let tip = NSPoint(x: anchor.x + 6 * cos(radians), y: anchor.y + 6 * sin(radians))

  func vertex(_ angle: CGFloat) -> NSPoint {
    NSPoint(x: tip.x + side * cos(angle), y: tip.y + side * sin(angle))
  }

  let path = NSBezierPath()
  path.move(to: tip)
  path.line(to: vertex(radians + spread))
  path.line(to: vertex(radians - spread))
  path.close()
  return path
}

func softShadow() -> NSShadow {
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
  shadow.shadowBlurRadius = 6
  shadow.shadowOffset = NSSize(width: 0, height: -2)
  return shadow
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

NSColor.white.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: pointSize)).fill()

for sticker in stickers {
  NSGraphicsContext.saveGraphicsState()

  let transform = NSAffineTransform()
  // The table gives centres from the top-left; the drawing space grows upward.
  transform.translateX(by: sticker.center.x, yBy: pointSize.height - sticker.center.y)
  transform.rotate(byDegrees: -sticker.rotation)
  transform.concat()

  let bubble = bubblePath()
  let cursor = cursorPath(corner: sticker.corner, heading: sticker.heading)

  softShadow().set()
  sticker.fill.setFill()
  bubble.fill()
  cursor.fill()

  NSShadow().set()
  NSColor.white.setStroke()
  bubble.lineWidth = 1.5
  bubble.stroke()
  cursor.lineWidth = 1.5
  cursor.lineJoinStyle = .round
  cursor.stroke()

  NSColor.white.setFill()
  let dotDiameter: CGFloat = 4.2
  for offset in [CGFloat(-7.5), 0, 7.5] {
    let dot = NSBezierPath(ovalIn: NSRect(
      x: offset - dotDiameter / 2,
      y: -dotDiameter / 2,
      width: dotDiameter,
      height: dotDiameter
    ))
    dot.fill()
  }

  NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
  fputs("cannot encode the disk image background\n", stderr)
  exit(1)
}

try png.write(to: outputURL, options: .atomic)
print("wrote \(outputURL.path) (\(bitmap.pixelsWide)x\(bitmap.pixelsHigh) px, \(Int(pointSize.width))x\(Int(pointSize.height)) pt)")
