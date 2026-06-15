// Renders the 1024×1024 app icon: a dark-academia design — a deep pine-green
// gradient background with a centered parchment open book (two curved pages
// meeting at a brass spine, a brass bookmark ribbon, faint text lines, and a
// soft drop shadow). Run: swift make_icon.swift [out.png]
import AppKit

let size = CGSize(width: 1024, height: 1024)

// Render into an explicit 1024×1024-pixel bitmap so the output is exactly
// 1024×1024 regardless of the display's backing scale factor.
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("could not create bitmap") }

let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Dark-academia palette: deep pine green, aged brass, parchment.
let pineTop = NSColor(calibratedRed: 0.165, green: 0.329, blue: 0.251, alpha: 1)    // #2A5440
let pineBottom = NSColor(calibratedRed: 0.075, green: 0.153, blue: 0.110, alpha: 1) // #13271C
let pineDeep = NSColor(calibratedRed: 0.040, green: 0.090, blue: 0.060, alpha: 1)   // shadow tone
let parchment = NSColor(calibratedRed: 0.929, green: 0.890, blue: 0.788, alpha: 1)  // #EDE3C9
let parchmentShade = NSColor(calibratedRed: 0.78, green: 0.73, blue: 0.62, alpha: 1)
let brass = NSColor(calibratedRed: 0.812, green: 0.663, blue: 0.306, alpha: 1)      // #CFA94E
let brassDeep = NSColor(calibratedRed: 0.62, green: 0.49, blue: 0.20, alpha: 1)     // ribbon shade

// 1. Background — full-bleed vertical gradient (lighter pine top → deep bottom).
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [pineTop.cgColor, pineBottom.cgColor] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: size.height),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Book geometry — centered, with a slight downward bias for optical balance.
let centerX = size.width / 2
let bookTop: CGFloat = 700      // top edge of the pages
let bookBottom: CGFloat = 300   // lowest point of the page bottoms
let pageInner: CGFloat = 26     // half-gap at the spine
let pageOuter: CGFloat = 386    // half-width to the outer page edge
let bottomDip: CGFloat = 70     // how far the bottom curves dip below the spine
let topRise: CGFloat = 44       // how far the top corners rise above the spine

// Builds one page as a closed path. `mirror` flips it to the left side.
func page(mirror: Bool) -> NSBezierPath {
    let s: CGFloat = mirror ? -1 : 1
    let innerX = centerX + s * pageInner
    let outerX = centerX + s * pageOuter
    let path = NSBezierPath()
    // Start at the spine top.
    path.move(to: NSPoint(x: innerX, y: bookTop))
    // Top edge curves gently up to the raised outer corner.
    path.curve(
        to: NSPoint(x: outerX, y: bookTop + topRise),
        controlPoint1: NSPoint(x: centerX + s * 170, y: bookTop + topRise * 0.4),
        controlPoint2: NSPoint(x: centerX + s * 300, y: bookTop + topRise)
    )
    // Outer edge down to the outer bottom corner.
    path.line(to: NSPoint(x: outerX, y: bookBottom + bottomDip))
    // Bottom edge curves upward toward the spine (open-book perspective).
    path.curve(
        to: NSPoint(x: innerX, y: bookBottom - bottomDip),
        controlPoint1: NSPoint(x: centerX + s * 300, y: bookBottom),
        controlPoint2: NSPoint(x: centerX + s * 150, y: bookBottom - bottomDip)
    )
    path.close()
    return path
}

let leftPage = page(mirror: true)
let rightPage = page(mirror: false)

// 2a. Brass bookmark ribbon — a narrow vertical strip hanging from the spine,
// drawn before the pages so the pages overlap its top (ribbon emerges from
// between them) and it extends slightly past the bottom page edge.
let ribbonWidth: CGFloat = 46
let ribbonTop = bookTop - 10                 // tucked just under the spine top
let ribbonBottom = bookBottom - bottomDip - 96 // hangs past the lowest page edge
context.saveGState()
let ribbonGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [brass.cgColor, brassDeep.cgColor] as CFArray,
    locations: [0, 1]
)!
let ribbonPath = NSBezierPath()
ribbonPath.move(to: NSPoint(x: centerX - ribbonWidth / 2, y: ribbonTop))
ribbonPath.line(to: NSPoint(x: centerX + ribbonWidth / 2, y: ribbonTop))
ribbonPath.line(to: NSPoint(x: centerX + ribbonWidth / 2, y: ribbonBottom + 24))
// Notched (swallowtail) bottom edge.
ribbonPath.line(to: NSPoint(x: centerX, y: ribbonBottom))
ribbonPath.line(to: NSPoint(x: centerX - ribbonWidth / 2, y: ribbonBottom + 24))
ribbonPath.close()
context.saveGState()
ribbonPath.addClip()
context.drawLinearGradient(
    ribbonGradient,
    start: CGPoint(x: centerX, y: ribbonTop),
    end: CGPoint(x: centerX, y: ribbonBottom),
    options: []
)
context.restoreGState()
context.restoreGState()

// 2b. Soft drop shadow beneath the book (blurred deep-pine shape).
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -26),
    blur: 48,
    color: pineDeep.withAlphaComponent(0.60).cgColor
)
pineDeep.withAlphaComponent(0.5).setFill()
let shadowPath = NSBezierPath()
shadowPath.append(leftPage)
shadowPath.append(rightPage)
shadowPath.fill()
context.restoreGState()

// 2c. The two parchment pages.
parchment.setFill()
leftPage.fill()
rightPage.fill()

// 3a. Faint text lines per page (slightly darker than parchment, low alpha).
parchmentShade.withAlphaComponent(0.50).setStroke()
func textLines(mirror: Bool) {
    let s: CGFloat = mirror ? -1 : 1
    let lineCount = 3
    for i in 0..<lineCount {
        let t = CGFloat(i) / CGFloat(lineCount - 1)
        let y = bookTop - 40 - t * 300
        // Lines follow the page: shorter near the curved bottom.
        let inset: CGFloat = 70 + t * 36
        let startX = centerX + s * (pageInner + 34)
        let endX = centerX + s * (pageOuter - inset)
        let line = NSBezierPath()
        line.lineWidth = 9
        line.lineCapStyle = .round
        // Slight curve to echo the page perspective.
        line.move(to: NSPoint(x: startX, y: y - t * 18))
        line.curve(
            to: NSPoint(x: endX, y: y),
            controlPoint1: NSPoint(x: centerX + s * 200, y: y - t * 10),
            controlPoint2: NSPoint(x: centerX + s * 300, y: y + 4)
        )
        line.stroke()
    }
}
textLines(mirror: true)
textLines(mirror: false)

// 3b. Spine — a thin brass groove where the pages meet. A soft parchment-shadow
// trough underneath gives depth, with a bright brass line down the center.
let spineTopY = bookTop - 4
let spineBottomY = bookBottom - bottomDip + 4

// Shadow trough: subtly darkens the parchment toward the spine on both sides.
let troughGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        parchmentShade.withAlphaComponent(0).cgColor,
        parchmentShade.withAlphaComponent(0.55).cgColor,
        parchmentShade.withAlphaComponent(0).cgColor
    ] as CFArray,
    locations: [0, 0.5, 1]
)!
context.saveGState()
let troughRect = NSRect(
    x: centerX - 40,
    y: spineBottomY - 4,
    width: 80,
    height: spineTopY - spineBottomY + 8
)
context.clip(to: troughRect)
context.drawLinearGradient(
    troughGradient,
    start: CGPoint(x: troughRect.minX, y: 0),
    end: CGPoint(x: troughRect.maxX, y: 0),
    options: []
)
context.restoreGState()

// Brass spine line — a slim gradient strip down the center.
let spineGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [brassDeep.cgColor, brass.cgColor, brassDeep.cgColor] as CFArray,
    locations: [0, 0.5, 1]
)!
context.saveGState()
let spineRect = NSRect(
    x: centerX - 7,
    y: spineBottomY,
    width: 14,
    height: spineTopY - spineBottomY
)
context.clip(to: spineRect)
context.drawLinearGradient(
    spineGradient,
    start: CGPoint(x: spineRect.minX, y: 0),
    end: CGPoint(x: spineRect.maxX, y: 0),
    options: []
)
context.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("could not encode png") }

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
