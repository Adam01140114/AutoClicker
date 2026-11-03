// Draws the app icon into an .iconset folder: swift tools/make-icon.swift build/AppIcon.iconset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size) / 1024

    // macOS icon grid: an 824pt rounded square centred on a 1024pt canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * s
    shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.36, green: 0.40, blue: 1.0, alpha: 1),
               ending: NSColor(red: 0.62, green: 0.24, blue: 0.92, alpha: 1))!.draw(in: shape, angle: -60)

    let config = NSImage.SymbolConfiguration(pointSize: 470 * s, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let r = NSRect(x: tile.midX - symbol.size.width / 2, y: tile.midY - symbol.size.height / 2,
                       width: symbol.size.width, height: symbol.size.height)
        symbol.draw(in: r)
    }

    // Small red "recording" dot in the corner.
    let dot = NSRect(x: 650 * s, y: 650 * s, width: 170 * s, height: 170 * s)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dot.insetBy(dx: -18 * s, dy: -18 * s)).fill()
    NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1).setFill()
    NSBezierPath(ovalIn: dot).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
