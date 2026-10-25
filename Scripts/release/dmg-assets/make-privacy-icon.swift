#!/usr/bin/env swift
import AppKit
import Foundation

/// Renders a Settings-style Privacy glyph into an .iconset directory.
/// Filenames with "@2x" are built at runtime (avoid tooling that mangles "name@…").
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : FileManager.default.currentDirectoryPath)

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let symbol = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil) else {
  fputs("error: SF Symbol hand.raised.fill unavailable\n", stderr)
  exit(1)
}

let at2x = "@" + "2x.png"
let configs: [(Int, String)] = [
  (16, "icon_16x16.png"),
  (32, "icon_16x16" + at2x),
  (32, "icon_32x32.png"),
  (64, "icon_32x32" + at2x),
  (128, "icon_128x128.png"),
  (256, "icon_128x128" + at2x),
  (256, "icon_256x256.png"),
  (512, "icon_256x256" + at2x),
  (512, "icon_512x512.png"),
  (1024, "icon_512x512" + at2x),
]

for (size, name) in configs {
  let px = CGFloat(size)
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  )!
  rep.size = NSSize(width: px, height: px)

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  let rect = NSRect(x: 0, y: 0, width: px, height: px)
  let radius = px * 0.22
  NSColor(calibratedRed: 0.22, green: 0.48, blue: 0.95, alpha: 1).setFill()
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

  let conf = NSImage.SymbolConfiguration(pointSize: px * 0.42, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
  let glyph = symbol.withSymbolConfiguration(conf) ?? symbol
  let gSize = glyph.size
  let target = px * 0.55
  let scale = min(target / max(gSize.width, 1), target / max(gSize.height, 1))
  let drawW = gSize.width * scale
  let drawH = gSize.height * scale
  glyph.draw(
    in: NSRect(x: (px - drawW) / 2, y: (px - drawH) / 2 - px * 0.02, width: drawW, height: drawH),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
  )

  NSGraphicsContext.restoreGraphicsState()

  guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("error: png encode \(name)\n", stderr)
    exit(1)
  }
  try png.write(to: outDir.appendingPathComponent(name))
}

print("iconset → \(outDir.path)")
