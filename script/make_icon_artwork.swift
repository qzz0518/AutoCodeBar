#!/usr/bin/env swift

import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make_icon_artwork.swift <out.png>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default
try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

enum Artwork {
    static let side = 1024
    static let bubble = CGRect(x: 133, y: 307, width: 758, height: 471)
    static let bubbleRadius: CGFloat = 96
    static let digitFontSize: CGFloat = 178
    static let digitTracking: CGFloat = 14.24 // 0.08 em
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [red / 255, green / 255, blue / 255, alpha]
    )!
}

/// One continuous outline for the rounded message body and its lower-left tail.
/// The two cubic tail segments replace part of the lower-left corner, so there
/// is no overlapping triangle, seam, or detached secondary shape.
func makeBubblePath() -> CGPath {
    let rect = Artwork.bubble
    let radius = Artwork.bubbleRadius
    let minX = rect.minX
    let maxX = rect.maxX
    let minY = rect.minY
    let maxY = rect.maxY
    let path = CGMutablePath()

    path.move(to: CGPoint(x: minX + radius, y: maxY))
    path.addLine(to: CGPoint(x: maxX - radius, y: maxY))
    path.addCurve(
        to: CGPoint(x: maxX, y: maxY - radius),
        control1: CGPoint(x: maxX - 43, y: maxY),
        control2: CGPoint(x: maxX, y: maxY - 43)
    )
    path.addLine(to: CGPoint(x: maxX, y: minY + radius))
    path.addCurve(
        to: CGPoint(x: maxX - radius, y: minY),
        control1: CGPoint(x: maxX, y: minY + 43),
        control2: CGPoint(x: maxX - 43, y: minY)
    )
    path.addLine(to: CGPoint(x: 337, y: minY))

    // Inner tail edge flows out of the body's bottom edge.
    path.addCurve(
        to: CGPoint(x: 207, y: 229),
        control1: CGPoint(x: 309, y: minY),
        control2: CGPoint(x: 271, y: 260)
    )
    // Outer tail edge flows directly into the body's left side.
    path.addCurve(
        to: CGPoint(x: minX, y: minY + radius),
        control1: CGPoint(x: 223, y: 274),
        control2: CGPoint(x: minX, y: 330)
    )
    path.addLine(to: CGPoint(x: minX, y: maxY - radius))
    path.addCurve(
        to: CGPoint(x: minX + radius, y: maxY),
        control1: CGPoint(x: minX, y: maxY - 43),
        control2: CGPoint(x: minX + 43, y: maxY)
    )
    path.closeSubpath()
    return path
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Artwork.side,
    pixelsHigh: Artwork.side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("cannot create bitmap\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("cannot create graphics context\n".utf8))
    exit(1)
}
NSGraphicsContext.current = graphicsContext
let context = graphicsContext.cgContext
context.setShouldAntialias(true)
context.setAllowsAntialiasing(true)
context.interpolationQuality = CGInterpolationQuality.high

let canvas = CGRect(x: 0, y: 0, width: Artwork.side, height: Artwork.side)
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [color(11, 122, 112), color(20, 168, 150)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 512, y: 0),
    end: CGPoint(x: 512, y: 1024),
    options: []
)

// One translucent light field is composited into the background treatment.
context.setFillColor(color(255, 255, 255, alpha: 0.08))
context.fillEllipse(in: CGRect(x: -220, y: 575, width: 850, height: 650))

let bubblePath = makeBubblePath()
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: color(0, 0, 0, alpha: 0.18))
context.addPath(bubblePath)
context.setFillColor(color(255, 255, 255))
context.fillPath()
context.restoreGState()

let baseFont = NSFont.systemFont(ofSize: Artwork.digitFontSize, weight: .heavy)
let roundedFont = baseFont.fontDescriptor.withDesign(.rounded).flatMap {
    NSFont(descriptor: $0, size: Artwork.digitFontSize)
} ?? baseFont
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let digits = NSAttributedString(
    string: "114514",
    attributes: [
        .font: roundedFont,
        .foregroundColor: NSColor(srgbRed: 15 / 255, green: 143 / 255, blue: 128 / 255, alpha: 1),
        .kern: Artwork.digitTracking,
        .paragraphStyle: paragraph,
    ]
)
let measured = digits.boundingRect(
    with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
)
let textRect = CGRect(
    x: Artwork.bubble.midX - measured.width / 2,
    y: Artwork.bubble.midY - measured.height / 2 + 3,
    width: measured.width,
    height: measured.height
)
digits.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    FileHandle.standardError.write(Data("cannot encode PNG\n".utf8))
    exit(1)
}
try png.write(to: outputURL, options: Data.WritingOptions.atomic)
print("wrote \(outputURL.path) (\(png.count) bytes, \(Artwork.side)x\(Artwork.side))")
