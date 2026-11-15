// Compiled with current production drawing sources by run.py; never part of the app.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let appearance = NSAppearance(named: .darkAqua)!
var metadata: [String: Any] = [:]

// Independent raster measurement: scan the exported PNG through its horizontal
// midpoint. Locate four alpha bands, then interpolate each half-opacity edge.
// This deliberately takes no ring radii, stroke metrics, or layout constants.
func measureDial(name: String, scale: Int) -> [String: Any] {
    let rep = NSBitmapImageRep(data: try! Data(contentsOf: output.appendingPathComponent("\(name)@\(scale)x.png")))!
    let y = rep.pixelsHigh / 2
    let alpha: [Double] = (0..<rep.pixelsWide).map { x in
        Double((rep.colorAt(x: x, y: y)!.alphaComponent + rep.colorAt(x: x, y: y - 1)!.alphaComponent) / 2)
    }
    var bands: [(left: Double, right: Double)] = []
    var x = 1
    while x < alpha.count - 1 {
        if alpha[x] < 0.1 { x += 1; continue }
        let first = x
        while x < alpha.count - 1 && alpha[x] >= 0.1 { x += 1 }
        let last = x - 1
        let half = alpha[first...last].max()! / 2
        var l = first
        var r = last
        while alpha[l] < half { l += 1 }
        while alpha[r] < half { r -= 1 }
        let left = Double(l) - 0.5 + Double((half - alpha[l-1]) / (alpha[l] - alpha[l-1]))
        let right = Double(r) + 0.5 + Double((alpha[r] - half) / (alpha[r] - alpha[r+1]))
        bands.append((left / Double(scale), right / Double(scale)))
    }
    precondition(bands.count == 4, "Expected four separate ring strokes on raster scanline")
    let timeline = ((bands[0].right-bands[0].left) + (bands[3].right-bands[3].left)) / 2
    let usage = ((bands[1].right-bands[1].left) + (bands[2].right-bands[2].left)) / 2
    let outer = bands[3].right-bands[0].left
    let usageOuter = bands[2].right-bands[1].left
    return ["scale": scale, "pngWidth": rep.pixelsWide, "pngHeight": rep.pixelsHigh,
        "timelineStroke": timeline, "outerDiameter": outer,
        "timelineCenterDiameter": outer-timeline,
        "timelineInnerDiameter": outer-2*timeline,
        "usageStroke": usage, "usageOuterDiameter": usageOuter,
        "usageCenterDiameter": usageOuter-usage,
        "openingDiameter": bands[2].left-bands[1].right,
        "ringGap": ((bands[1].left-bands[0].right) + (bands[3].left-bands[2].right)) / 2,
        "scanBandsPt": bands.map { [$0.left, $0.right] }]
}

func export(_ image: NSImage, name: String, scale: Int) {
    let width = Int(ceil(image.size.width * CGFloat(scale)))
    let height = Int(ceil(image.size.height * CGFloat(scale)))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: CGFloat(width) / CGFloat(scale), height: CGFloat(height) / CGFloat(scale))
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    // NSBitmapImageRep.size already establishes the points-to-pixels transform.
    image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)@\(scale)x.png"))
}

appearance.performAsCurrentDrawingAppearance {
    let warning = NSColor(calibratedRed: 1, green: 0.55, blue: 0.05, alpha: 1)
    let rgb = warning.usingColorSpace(.sRGB)!
    metadata["warningSRGB"] = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
    let values: [(Double, Double)] = [(91, 84), (99, 84), (36, 37)]
    for variant in ["A", "B"] {
        for sample in ["row", "dial"] {
            let selected = sample == "row" ? values : [values[0]]
            let image: NSImage
            if variant == "A" {
                image = RingIcon.image(look: .ringsPerQuota, dials: selected.enumerated().map { index, pair in
                    RingIcon.Dial(avatar: index == 2 ? .grok : .cursor, showAvatar: false,
                        usedPcts: [pair.0], brandColors: [index == 2 ? nil : warning],
                        elapsedPct: pair.1, remaining: nil, displayedUsedIndex: 0)
                }, showAvatarsBeside: false, showUsedPercent: sample == "row", showElapsedPercent: sample == "row",
                showRemainingBeside: false, ringCenter: .none, colorMode: .byLevel,
                onPaceLo: 0.9, onPaceHi: 1.1, foreground: .white, paceColor: { _ in warning })
            } else {
                image = RingIconDouble.image(look: .ringsPerQuota, dials: selected.enumerated().map { index, pair in
                    RingIconDouble.Dial(avatar: index == 2 ? .grok : .cursor, showAvatar: false,
                        usedPcts: [pair.0], brandColors: [index == 2 ? nil : warning],
                        elapsedPct: pair.1, remaining: nil, displayedUsedIndex: 0)
                }, showAvatarsBeside: false, showUsedPercent: sample == "row", showElapsedPercent: sample == "row",
                showRemainingBeside: false, ringCenter: .none, colorMode: .byLevel,
                onPaceLo: 0.9, onPaceHi: 1.1, foreground: .white, paceColor: { _ in warning })
            }
            metadata["\(variant)-\(sample)"] = ["width": image.size.width, "height": image.size.height]
            for scale in [1, 2, 4, 8, 16] { export(image, name: "\(variant)-\(sample)", scale: scale) }
            if sample == "dial" { metadata["\(variant)-measured"] = measureDial(name: "\(variant)-dial", scale: 16) }
            if sample == "row" {
                let png = NSBitmapImageRep(data: try! Data(contentsOf: output.appendingPathComponent("\(variant)-row@16x.png")))!
                metadata["\(variant)-raster"] = ["width": Double(png.pixelsWide)/16, "height": Double(png.pixelsHigh)/16,
                    "pixelsWide": png.pixelsWide, "pixelsHigh": png.pixelsHigh]
            }
        }
    }
}
let data = try! JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: output.appendingPathComponent("native.json"))
