import Foundation

/// Pure CSS generation for the chapter web view. Kept free of UIKit so
/// it is trivially unit-testable.
enum ReaderStyle {

    /// Top clears the Dynamic Island plus the title bar; bottom clears
    /// the home indicator. The chrome bars overlay these margins.
    static let topPadding: Double = 96
    static let bottomPadding: Double = 72

    /// The stylesheet injected into every chapter document.
    ///
    /// Paged flow lays the chapter out in viewport-wide CSS columns that
    /// overflow horizontally into the html element; turning a page
    /// scrolls html to the next column (driven from Swift via the
    /// scroll view, see ReaderController). Scroll flow leaves the
    /// document in normal vertical flow and lets the scroll view move it.
    static func css(settings: ReaderSettings, pageWidth: Double,
                    pageHeight: Double, systemDark: Bool = false) -> String {
        let theme = settings.palette(systemDark: systemDark)
        let margin = settings.horizontalMargin
        let contentWidth = pageWidth - margin * 2
        let textHeight = pageHeight - topPadding - bottomPadding

        let layout: String
        switch settings.pageFlow {
        case .paged:
            layout = """
            html {
                /* The real (programmatic) horizontal scroller. WebKit
                   paints tiles around the scroll position, unlike a
                   transformed body which can arrive blank. The body's
                   columns overflow into here; html scrolls them and
                   clips the vertical edge. User panning stays disabled
                   natively. */
                overflow-x: auto !important;
                overflow-y: hidden !important;
                height: \(pageHeight)px !important;
                background: \(theme.backgroundHex) !important;
            }
            body {
                margin: 0 !important;
                padding: \(topPadding)px \(margin)px \(bottomPadding)px !important;
                box-sizing: border-box;
                height: \(pageHeight)px !important;
                width: \(pageWidth)px !important;
                max-width: none !important;
                /* overflow must stay visible: the extra columns flow
                   past the body box into html, which scrolls them. A
                   hidden body would clip every page but the first. */
                overflow: visible !important;
                column-width: \(contentWidth)px;
                column-gap: \(margin * 2)px;
                column-fill: auto;
            }
            #lumen-eink {
                position: fixed;
                inset: 0;
                /* A real e-ink full refresh flashes to solid ink. Use the
                   dark ink in every theme — in dark themes the text
                   colour is light, which would flash white. */
                background: \(theme.isDark ? "#000000" : theme.textHex);
                opacity: 0;
                pointer-events: none;
                /* Clearing the fill: a quick, crisp wipe back to the page. */
                transition: opacity 70ms linear;
                z-index: 99;
            }
            #lumen-eink.lumen-eink-on {
                /* Full, opaque ink. Snap it on almost instantly so the
                   blink reads as a deliberate refresh, not a fade-in. */
                opacity: 1;
                transition: opacity 16ms linear;
            }
            """
        case .scroll:
            layout = """
            html {
                background: \(theme.backgroundHex) !important;
            }
            body {
                margin: 0 !important;
                padding: \(topPadding)px \(margin)px \(bottomPadding)px !important;
                box-sizing: border-box;
                width: \(pageWidth)px !important;
                max-width: \(pageWidth)px !important;
            }
            """
        }

        return """
        :root { color-scheme: \(theme.isDark ? "dark" : "light"); }
        \(layout)
        body {
            background: \(theme.backgroundHex) !important;
            color: \(theme.textHex) !important;
            font-family: \(settings.font.cssFamily) !important;
            font-size: \(settings.fontSize)px !important;
            line-height: \(settings.lineHeight) !important;
            text-align: \(settings.isJustified ? "justify" : "left");
            -webkit-hyphens: auto;
            hyphens: auto;
            text-rendering: optimizeLegibility;
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
        img, svg, image, picture, video, object, .calibre1, .calibre2 {
            display: block !important;
            width: auto !important;
            height: auto !important;
            max-width: \(contentWidth)px !important;
            max-height: \(textHeight)px !important;
            object-fit: contain !important;
            break-inside: avoid;
            margin-left: auto !important;
            margin-right: auto !important;
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
        mark.lumen-highlight {
            /* 8-digit hex: accent at ~30% over the page keeps the ink
               readable in every theme. */
            background: \(theme.accentHex)4D !important;
            color: inherit !important;
            border-radius: 2px;
            padding: 0.06em 0;
        }
        """
    }
}
