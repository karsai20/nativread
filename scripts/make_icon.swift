// Renders the 1024×1024 app icon: deep lantern-green gradient, a cream
// serif italic "L" and a thin amber beam line. Run: swift make_icon.swift
import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Background gradient.
let colors = [
    NSColor(calibratedRed: 0.16, green: 0.27, blue: 0.24, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.10, alpha: 1).cgColor
]
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: size.width, y: 0),
    options: []
)

// Amber beam.
let amber = NSColor(calibratedRed: 0.91, green: 0.69, blue: 0.29, alpha: 1)
amber.withAlphaComponent(0.85).setFill()
NSBezierPath(rect: NSRect(x: 132, y: 196, width: 760, height: 10)).fill()

// Serif italic monogram.
let font = NSFont(name: "Georgia-BoldItalic", size: 640)
    ?? NSFont.systemFont(ofSize: 640, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(
        calibratedRed: 0.93, green: 0.89, blue: 0.80, alpha: 1
    )
]
let letter = NSAttributedString(string: "L", attributes: attributes)
let bounds = letter.boundingRect(
    with: size, options: [.usesLineFragmentOrigin]
)
letter.draw(at: CGPoint(
    x: (size.width - bounds.width) / 2 - bounds.minX,
    y: (size.height - bounds.height) / 2 - bounds.minY + 60
))

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let representation = NSBitmapImageRep(data: tiff),
    let png = representation.representation(using: .png, properties: [:])
else { fatalError("could not encode png") }

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
