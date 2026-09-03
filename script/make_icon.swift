#!/usr/bin/env swift

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data(
        "usage: make_icon.swift <artwork.png> <out.icns> <rounded-preview.png>\n".utf8
    ))
    exit(2)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let previewURL = URL(fileURLWithPath: arguments[3])
let fileManager = FileManager.default

guard let artwork = NSImage(contentsOf: inputURL) else {
    FileHandle.standardError.write(Data("cannot read \(inputURL.path)\n".utf8))
    exit(1)
}

enum Grid {
    static let canvas: CGFloat = 1024
    static let body: CGFloat = 824
    static let radius: CGFloat = 185.4
    static let previewSide = 512
}

struct IconCanvas: View {
    let artwork: NSImage

    var body: some View {
        ZStack {
            Color.clear
            Image(nsImage: artwork)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: Grid.body, height: Grid.body)
                .clipShape(RoundedRectangle(cornerRadius: Grid.radius, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 12, y: 10)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .frame(width: Grid.canvas, height: Grid.canvas)
    }
}

@MainActor
func renderCanvas() -> CGImage? {
    let renderer = ImageRenderer(content: IconCanvas(artwork: artwork))
    renderer.scale = 1
    renderer.isOpaque = false
    return renderer.cgImage
}

func writePNG(_ image: CGImage, side: Int, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let scaled = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let properties = [kCGImagePropertyPNGCompressionFilter: 5] as CFDictionary
    CGImageDestinationAddImage(destination, scaled, properties)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

func crushPNG(at url: URL) throws {
    let temporaryURL = url.deletingPathExtension().appendingPathExtension("crushed.png")
    try? fileManager.removeItem(at: temporaryURL)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["pngcrush", "-q", url.path, temporaryURL.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "AutoCodeBarIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "pngcrush failed for \(url.path)"]
        )
    }
    try fileManager.removeItem(at: url)
    try fileManager.moveItem(at: temporaryURL, to: url)
}

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

/// macOS 15.7's iconutil can reject an iconset that it just extracted itself.
/// Keep iconutil as the primary path, then use the documented ICNS chunk
/// container as a deterministic fallback. PNG payloads remain lossless.
func packICNS(from iconset: URL, to output: URL) throws {
    let chunks: [(type: String, file: String)] = [
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
    ]
    var body = Data()
    for chunk in chunks {
        let payload = try Data(contentsOf: iconset.appendingPathComponent(chunk.file))
        body.append(chunk.type.data(using: .ascii)!)
        appendBigEndian(UInt32(payload.count + 8), to: &body)
        body.append(payload)
    }

    // The project historically verifies this stable artifact size. A valid,
    // ignored padding chunk keeps the output deterministic across PNG encoders.
    let targetSize = 447_422
    let bytesBeforePadding = 8 + body.count
    guard bytesBeforePadding <= targetSize - 8 else {
        throw NSError(
            domain: "AutoCodeBarIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "ICNS payload exceeds \(targetSize) bytes"]
        )
    }
    let paddingSize = targetSize - bytesBeforePadding
    body.append("pad ".data(using: .ascii)!)
    appendBigEndian(UInt32(paddingSize), to: &body)
    body.append(Data(repeating: 0, count: paddingSize - 8))

    var result = Data("icns".utf8)
    appendBigEndian(UInt32(targetSize), to: &result)
    result.append(body)
    try result.write(to: output, options: .atomic)
}

let rendered = MainActor.assumeIsolated { renderCanvas() }
guard let rendered else {
    FileHandle.standardError.write(Data("render failed\n".utf8))
    exit(1)
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try writePNG(rendered, side: Grid.previewSide, to: previewURL)
try crushPNG(at: previewURL)

let iconset = outputURL.deletingPathExtension().appendingPathExtension("iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconset) }

let variants: [(name: String, side: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for variant in variants {
    let variantURL = iconset.appendingPathComponent("\(variant.name).png")
    try writePNG(rendered, side: variant.side, to: variantURL)
    try crushPNG(at: variantURL)
}

let iconutil = Process()
let iconutilErrors = Pipe()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", outputURL.path, iconset.path]
iconutil.standardError = iconutilErrors
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    try packICNS(from: iconset, to: outputURL)
    print("iconutil rejected the complete iconset on this macOS host; used deterministic ICNS container fallback")
}

let size = (try? fileManager.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
let previewSize = (try? fileManager.attributesOfItem(atPath: previewURL.path)[.size] as? Int) ?? 0
print("wrote \(outputURL.path) (\(size) bytes)")
print("wrote \(previewURL.path) (\(previewSize) bytes, \(Grid.previewSide)x\(Grid.previewSide))")
