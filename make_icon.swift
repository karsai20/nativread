#!/usr/bin/env swift
// Run with: swift make_icon.swift
// Generates the Verso app icon (1024x1024) into the asset catalog.

import CoreGraphics
import ImageIO
import Foundation

let size: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: bitmapInfo.rawValue
) else { fatalError("Could not create CGContext") }

ctx.saveGState()

// ── Background: deep ink (#181C24)
ctx.setFillColor(CGColor(srgbRed: 0.094, green: 0.110, blue: 0.141, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// ── Warm accent line (left margin rule, terracotta #B85C38)
let ruleX: CGFloat = size * 0.14
let ruleTop: CGFloat = size * 0.22
let ruleBottom: CGFloat = size * 0.78
ctx.setStrokeColor(CGColor(srgbRed: 0.722, green: 0.361, blue: 0.220, alpha: 0.85))
ctx.setLineWidth(size * 0.018)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: ruleX, y: ruleTop))
ctx.addLine(to: CGPoint(x: ruleX, y: ruleBottom))
ctx.strokePath()

// ── Text lines (warm off-white, varying widths like real text)
let lineColor = CGColor(srgbRed: 0.94, green: 0.91, blue: 0.85, alpha: 1)
let lineHeight: CGFloat = size * 0.048
let lineSpacing: CGFloat = size * 0.082
let lineLeft: CGFloat = ruleX + size * 0.07
let lineWidths: [CGFloat] = [0.62, 0.54, 0.68, 0.44, 0.60]
let totalBlock: CGFloat = CGFloat(lineWidths.count - 1) * lineSpacing
let startY: CGFloat = (size - totalBlock) / 2 + lineSpacing * 0.5

ctx.setFillColor(lineColor)
for (i, fraction) in lineWidths.enumerated() {
    let y = startY + CGFloat(i) * lineSpacing - lineHeight / 2
    let w = (size - lineLeft - size * 0.12) * fraction
    let rect = CGRect(x: lineLeft, y: y, width: w, height: lineHeight)
    let radius = lineHeight * 0.38
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()
}

// ── "V" letterform hint (very subtle, large, bottom-right)
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.04))
let vSize: CGFloat = size * 0.55
let vX: CGFloat = size * 0.52
let vY: CGFloat = size * 0.48
// Left stroke of V
let vPath = CGMutablePath()
vPath.move(to: CGPoint(x: vX, y: vY))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.38, y: vY + vSize * 0.7))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.38 + vSize * 0.08, y: vY + vSize * 0.7))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.08, y: vY))
vPath.closeSubpath()
// Right stroke of V
vPath.move(to: CGPoint(x: vX + vSize * 0.38, y: vY + vSize * 0.7))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.76, y: vY))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.68, y: vY))
vPath.addLine(to: CGPoint(x: vX + vSize * 0.38 - vSize * 0.04, y: vY + vSize * 0.62))
vPath.closeSubpath()
ctx.addPath(vPath)
ctx.fillPath()

ctx.restoreGState()

// ── Save PNG
guard let image = ctx.makeImage() else { fatalError("Could not make image") }

let outputPath = "LumenRead/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
let url = URL(fileURLWithPath: outputPath)

guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Could not create image destination at \(outputPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write PNG") }

print("✅ Icon written to \(outputPath)")
print("   Run `xcodegen generate` to regenerate the project.")
