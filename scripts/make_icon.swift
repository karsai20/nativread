// Renders the 1024×1024 app icon: a warm terracotta gradient background with a
// centered cream open book (two curved pages meeting at a spine, faint text
// lines, and a soft drop shadow). Run: swift make_icon.swift [out.png]
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

// Palette around accent #9A3B2E.
let terracottaTop = NSColor(calibratedRed: 0.70, green: 0.32, blue: 0.25, alpha: 1)
let terracottaBottom = NSColor(calibratedRed: 0.48, green: 0.16, blue: 0.12, alpha: 1)
let terracottaDeep = NSColor(calibratedRed: 0.38, green: 0.12, blue: 0.09, alpha: 1)
let cream = NSColor(calibratedRed: 0.957, green: 0.918, blue: 0.847, alpha: 1)
let creamShade = NSColor(calibratedRed: 0.86, green: 0.80, blue: 0.71, alpha: 1)

// 1. Background — full-bleed vertical gradient (lighter top → deeper bottom).
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [terracottaTop.cgColor, terracottaBottom.cgColor] as CFArray,
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

// 2a. Soft drop shadow beneath the book (blurred deep-terracotta shape).
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -26),
    blur: 48,
    color: terracottaDeep.withAlphaComponent(0.55).cgColor
)
terracottaDeep.withAlphaComponent(0.5).setFill()
let shadowPath = NSBezierPath()
shadowPath.append(leftPage)
shadowPath.append(rightPage)
shadowPath.fill()
context.restoreGState()

// 2b. The two cream pages.
cream.setFill()
leftPage.fill()
rightPage.fill()

// 3a. Faint text lines per page (slightly darker than cream, low alpha).
creamShade.withAlphaComponent(0.55).setStroke()
func textLines(mirror: Bool) {
    let s: CGFloat = mirror ? -1 : 1
    let lineCount = 5
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

// 3b. Spine — a thin deeper-terracotta groove where the pages meet.
let spineGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        terracottaDeep.withAlphaComponent(0).cgColor,
        terracottaDeep.withAlphaComponent(0.65).cgColor,
        terracottaDeep.withAlphaComponent(0).cgColor
    ] as CFArray,
    locations: [0, 0.5, 1]
)!
context.saveGState()
let spineRect = NSRect(
    x: centerX - 34,
    y: bookBottom - bottomDip - 4,
    width: 68,
    height: (bookTop + topRise) - (bookBottom - bottomDip) + 8
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
