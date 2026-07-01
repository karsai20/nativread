import PDFKit
import UIKit
import CoreImage

/// A PDF page that renders with a hue-preserving luminance inversion for
/// night reading: black text becomes light on a dark page while colour
/// images keep their hue. `CIColorInvert` flips both lightness *and* hue;
/// the following 180° hue rotation flips hue back, leaving only the
/// lightness inverted — the PDF-Expert "smart invert", not a naive
/// `1 - rgb` that turns photographs into negatives.
///
/// Selection, links and search keep working because they operate on the
/// page model, not on these rendered pixels.
final class NightInvertPDFPage: PDFPage {

    // ponytail: one shared CIContext, GPU-backed. Rasterising on every
    // draw is the known cost of night mode — cache a bitmap per page only
    // if scrolling large PDFs stutters.
    private static let ciContext = CIContext()

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        let pageBounds = bounds(for: box)
        guard pageBounds.width > 0, pageBounds.height > 0 else {
            super.draw(with: box, to: context)
            return
        }

        // Opaque + white-filled: most PDF pages have no background fill, so
        // PDFKit paints the white page paper *behind* this draw. Without an
        // opaque white base the inverted (transparent) render lets that white
        // show through — the page reads light, not dark. Filling white here,
        // then inverting, yields a solid dark page that covers the backing.
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pageBounds.size, format: format)
        let rendered = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: pageBounds.size))
            // PDFKit on iOS already orients the page upright in the
            // UIKit (top-left) context the renderer provides, so no manual
            // flip is needed; only shift for a non-zero crop-box origin.
            cg.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
            super.draw(with: box, to: cg)
        }

        let output = Self.nightFiltered(rendered) ?? rendered
        UIGraphicsPushContext(context)
        output.draw(in: pageBounds)
        UIGraphicsPopContext()
    }

    /// Inverts lightness while preserving hue. Returns nil if the filter
    /// chain is unavailable, so the caller can fall back to the original.
    static func nightFiltered(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image),
              let invert = CIFilter(name: "CIColorInvert")
        else { return nil }
        invert.setValue(input, forKey: kCIInputImageKey)

        guard let inverted = invert.outputImage,
              let hue = CIFilter(name: "CIHueAdjust")
        else { return nil }
        hue.setValue(inverted, forKey: kCIInputImageKey)
        hue.setValue(Float.pi, forKey: kCIInputAngleKey)

        guard let result = hue.outputImage,
              let cgImage = ciContext.createCGImage(result, from: input.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
