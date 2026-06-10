import Foundation

/// Pure CSS generation for the chapter web view. Kept free of UIKit so
/// it is trivially unit-testable.
enum ReaderStyle {

    /// Top clears the Dynamic Island plus the title bar; bottom clears
    /// the home indicator. The chrome bars overlay these margins.
    static let topPadding: Double = 96
    static let bottomPadding: Double = 72

    /// The stylesheet injected into every chapter document. Pagination
    /// works by laying the chapter out in viewport-wide CSS columns and
    /// translating the body horizontally, one page per column.
    static func css(settings: ReaderSettings, pageWidth: Double,
                    pageHeight: Double) -> String {
        let theme = settings.theme
        let margin = settings.horizontalMargin
        let columnWidth = pageWidth - margin * 2
        let textHeight = pageHeight - topPadding - bottomPadding
        return """
        :root { color-scheme: \(theme.isDark ? "dark" : "light"); }
        html {
            overflow: hidden !important;
            background: \(theme.backgroundHex) !important;
        }
        body {
            margin: 0 !important;
            padding: \(topPadding)px \(margin)px \(bottomPadding)px !important;
            box-sizing: border-box;
            height: \(pageHeight)px !important;
            width: auto !important;
            max-width: none !important;
            overflow: hidden !important;
            column-width: \(columnWidth)px;
            column-gap: \(margin * 2)px;
            column-fill: auto;
            background: \(theme.backgroundHex) !important;
            color: \(theme.textHex) !important;
            font-family: \(settings.font.cssFamily) !important;
            font-size: \(settings.fontSize)px !important;
            line-height: \(settings.lineHeight) !important;
            text-align: \(settings.isJustified ? "justify" : "left");
            -webkit-hyphens: auto;
            hyphens: auto;
            text-rendering: optimizeLegibility;
            will-change: transform;
        }
        body.lumen-animate {
            transition: transform 240ms cubic-bezier(0.22, 1, 0.36, 1);
        }
        body * {
            color: inherit !important;
            background-color: transparent !important;
            font-family: inherit !important;
            line-height: inherit !important;
            max-width: 100% !important;
        }
        p { margin: 0 0 0.65em 0; }
        h1, h2, h3, h4, h5, h6 {
            line-height: 1.25 !important;
            text-align: left;
            break-after: avoid;
        }
        img, svg, video {
            max-width: \(columnWidth)px !important;
            max-height: \(textHeight)px !important;
            height: auto !important;
            object-fit: contain;
            break-inside: avoid;
        }
        a { color: \(theme.accentHex) !important; text-decoration: none; }
        blockquote {
            border-left: 2px solid \(theme.accentHex);
            margin-left: 0;
            padding-left: 1em;
            font-style: italic;
        }
        mark.lumen-find {
            background: \(theme.accentHex) !important;
            color: \(theme.backgroundHex) !important;
            border-radius: 2px;
        }
        """
    }
}
