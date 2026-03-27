import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("build/Icon.iconset", isDirectory: true)
let outputURL = root.appendingPathComponent("Resources/ProcessBarMonitor.icns")
try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.03, dy: size * 0.03), xRadius: radius, yRadius: radius)
    bg.addClip()

    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.17, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.73, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.86, alpha: 1).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0, 0.55, 1]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])

    let innerRect = rect.insetBy(dx: size * 0.14, dy: size * 0.14)
    let panel = NSBezierPath(roundedRect: innerRect, xRadius: size * 0.12, yRadius: size * 0.12)
    NSColor.white.withAlphaComponent(0.12).setFill()
    panel.fill()

    let gridPath = NSBezierPath()
    gridPath.lineWidth = max(2, size * 0.012)
    NSColor.white.withAlphaComponent(0.08).setStroke()
    for i in 1...3 {
        let y = innerRect.minY + CGFloat(i) * innerRect.height / 4
        gridPath.move(to: CGPoint(x: innerRect.minX, y: y))
        gridPath.line(to: CGPoint(x: innerRect.maxX, y: y))
    }
    gridPath.stroke()

    let chart = NSBezierPath()
    chart.lineWidth = max(4, size * 0.04)
    chart.lineCapStyle = .round
    chart.lineJoinStyle = .round
    let points = [
        CGPoint(x: innerRect.minX + innerRect.width * 0.06, y: innerRect.minY + innerRect.height * 0.28),
        CGPoint(x: innerRect.minX + innerRect.width * 0.24, y: innerRect.minY + innerRect.height * 0.54),
        CGPoint(x: innerRect.minX + innerRect.width * 0.43, y: innerRect.minY + innerRect.height * 0.40),
        CGPoint(x: innerRect.minX + innerRect.width * 0.62, y: innerRect.minY + innerRect.height * 0.74),
        CGPoint(x: innerRect.minX + innerRect.width * 0.82, y: innerRect.minY + innerRect.height * 0.60),
        CGPoint(x: innerRect.minX + innerRect.width * 0.94, y: innerRect.minY + innerRect.height * 0.82)
    ]
    chart.move(to: points[0])
    for point in points.dropFirst() { chart.line(to: point) }
    NSColor.white.setStroke()
    chart.stroke()

    let dotColors: [NSColor] = [
        NSColor(calibratedRed: 0.36, green: 0.98, blue: 0.73, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.79, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.36, alpha: 1)
    ]
    let dotIndexes = [1, 3, 5]
    for (offset, idx) in dotIndexes.enumerated() {
        let p = points[idx]
        let dotRect = CGRect(x: p.x - size * 0.05, y: p.y - size * 0.05, width: size * 0.10, height: size * 0.10)
        let dot = NSBezierPath(ovalIn: dotRect)
        dotColors[offset].setFill()
        dot.fill()
        NSColor.white.withAlphaComponent(0.8).setStroke()
        dot.lineWidth = max(1.5, size * 0.008)
        dot.stroke()
    }

    let gloss = NSBezierPath(roundedRect: CGRect(x: innerRect.minX, y: innerRect.midY, width: innerRect.width, height: innerRect.height * 0.5), xRadius: size * 0.12, yRadius: size * 0.12)
    NSColor.white.withAlphaComponent(0.05).setFill()
    gloss.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 1)
    }
    try data.write(to: url)
}

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in specs {
    try writePNG(drawIcon(size: size), to: iconsetURL.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try task.run()
task.waitUntilExit()
if task.terminationStatus != 0 {
    throw NSError(domain: "Icon", code: Int(task.terminationStatus))
}

print(outputURL.path)
