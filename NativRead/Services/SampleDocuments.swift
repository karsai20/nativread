import UIKit

/// Generates throwaway sample PDF / TXT files for UI-test seeding and
/// screenshot automation, so the real import pipeline (not a hand-built
/// `library.json`) is exercised. Written to the temp directory.
enum SampleDocuments {

    static func makePDF(languageCode: String? = nil) -> URL? {
        let isHungarian = languageCode == "hu"
        let title = isHungarian ? "Minta PDF" : "Sample PDF"
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextAuthor as String: "NativRead"
        ]
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(title).pdf")
        let sentence = isHungarian
            ? "Ez a minta PDF törzsszövege, amellyel a rögzített "
                + "oldalelrendezést, a színeket megőrző éjszakai módot, "
                + "a keresést és a natív szövegkijelölést ellenőrizzük. "
            : "This is sample PDF body text used to verify fixed-"
                + "layout paging, the hue-preserving night invert, search "
                + "and native text selection. "
        let body = String(
            repeating: sentence,
            count: 14
        ) as NSString
        do {
            try renderer.writePDF(to: url) { context in
                for page in 1...3 {
                    context.beginPage()
                    let chapterTitle = (
                        isHungarian
                            ? "\(page). fejezet"
                            : "Chapter \(page)"
                    ) as NSString
                    chapterTitle.draw(
                        at: CGPoint(x: 60, y: 80),
                        withAttributes: [.font: UIFont.boldSystemFont(ofSize: 30)]
                    )
                    body.draw(
                        in: CGRect(x: 60, y: 150, width: 492, height: 460),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 17)]
                    )
                    // A saturated block proves night invert keeps image hue
                    // rather than flipping blue to orange.
                    UIColor.systemBlue.setFill()
                    UIBezierPath(
                        rect: CGRect(x: 60, y: 640, width: 220, height: 90)
                    ).fill()
                }
            }
            return url
        } catch {
            return nil
        }
    }

    static func makeText() -> URL? {
        let text = """
        Sample Text Document

        This is the first paragraph of a plain text file imported into \
        NativRead. It reflows with the reader's themes, fonts and margins \
        because it is wrapped into a synthesized chapter.

        This is a second paragraph. Selecting a word such as lantern offers \
        the native iOS text menu, just like an EPUB.
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sample Text.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
