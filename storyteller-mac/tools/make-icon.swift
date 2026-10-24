// Renders the app icon (amber book on a dark rounded square) to a 1024px PNG.
// Usage: swift tools/make-icon.swift Resources/AppIcon.png
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let size = 1024.0
let accent = NSColor(red: 0.902, green: 0.722, blue: 0.408, alpha: 1)
let accentDeep = NSColor(red: 0.851, green: 0.604, blue: 0.306, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt rounded square centered in 1024.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSGradient(starting: NSColor(red: 0.17, green: 0.175, blue: 0.21, alpha: 1),
           ending: NSColor(red: 0.047, green: 0.051, blue: 0.066, alpha: 1))!.draw(in: shape, angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.14).setStroke()
shape.lineWidth = 4
shape.stroke()

// Soft amber glow behind the book.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [accent.withAlphaComponent(0.28), accent.withAlphaComponent(0)])!
    .draw(fromCenter: NSPoint(x: 512, y: 500), radius: 0, toCenter: NSPoint(x: 512, y: 500), radius: 440, options: [])
NSGraphicsContext.restoreGraphicsState()

// The book symbol, filled with the accent gradient.
let config = NSImage.SymbolConfiguration(pointSize: 580, weight: .regular)
let symbol = NSImage(systemSymbolName: "book.pages.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
let s = symbol.size
let rect = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2 - 8, width: s.width, height: s.height)
let tinted = NSImage(size: s, flipped: false) { r in
    symbol.draw(in: r)
    NSGraphicsContext.current?.compositingOperation = .sourceIn
    NSGradient(starting: accent, ending: accentDeep)!.draw(in: r, angle: -90)
    return true
}
tinted.draw(in: rect)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
