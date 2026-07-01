import XCTest
import UIKit
import PDFKit
@testable import NativRead

final class NightInvertTests: XCTestCase {

    /// Renders a solid colour image for filtering.
    private func solid(_ color: UIColor, size: CGFloat = 8) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        return UIGraphicsImageRenderer(size: bounds.size).image { ctx in
            color.setFill()
            ctx.fill(bounds)
        }
    }

    /// Average RGBA (0...1) of an image's pixels.
    private func averageRGBA(_ image: UIImage) -> (r: Double, g: Double, b: Double, a: Double) {
        guard let cg = image.cgImage else { return (0, 0, 0, 0) }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var sum = (r: 0.0, g: 0.0, b: 0.0, a: 0.0)
        let count = width * height
        for i in 0..<count {
            sum.r += Double(pixels[i * 4 + 0])
            sum.g += Double(pixels[i * 4 + 1])
            sum.b += Double(pixels[i * 4 + 2])
            sum.a += Double(pixels[i * 4 + 3])
        }
        return (sum.r / Double(count) / 255, sum.g / Double(count) / 255,
                sum.b / Double(count) / 255, sum.a / Double(count) / 255)
    }

    func testWhiteInvertsToDark() throws {
        let output = try XCTUnwrap(
            NightInvertPDFPage.nightFiltered(solid(.white))
        )
        let avg = averageRGBA(output)
        XCTAssertLessThan(avg.r, 0.2, "white page should invert to near-black")
        XCTAssertLessThan(avg.g, 0.2)
        XCTAssertLessThan(avg.b, 0.2)
    }

    func testBlackInvertsToLight() throws {
        let output = try XCTUnwrap(
            NightInvertPDFPage.nightFiltered(solid(.black))
        )
        let avg = averageRGBA(output)
        XCTAssertGreaterThan(avg.r, 0.8, "black text should invert to near-white")
    }

    func testBlueKeepsHueWhileLightening() throws {
        let output = try XCTUnwrap(
            NightInvertPDFPage.nightFiltered(solid(.systemBlue))
        )
        let avg = averageRGBA(output)
        // Hue preserved: blue still dominates red/green after the invert.
        XCTAssertGreaterThan(avg.b, avg.r, "blue should remain blue, not become orange")
        XCTAssertGreaterThan(avg.b, avg.g)
    }
}
