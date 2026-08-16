import Foundation

/// Pure CSS generation for the chapter web view. Kept free of UIKit so
/// it is trivially unit-testable.
enum ReaderStyle {

    /// Top clears the Dynamic Island plus the title bar; bottom clears
    /// the home indicator. The chrome bars overlay these margins.
    static let topPadding: Double = 96
    static let bottomPadding: Double = 72
    /// Compact-height landscape needs breathing room around the chrome, but
    /// not the portrait-sized gutters that would consume almost half a page.
    static let landscapeTopPadding: Double = 64
    static let landscapeBottomPadding: Double = 44
    /// Fallback for edge-to-edge WebKit layouts where UIKit can briefly
    /// report zero horizontal safe-area insets during rotation. Symmetric
    /// compact-height gutters keep either landscape orientation clear of the
    /// sensor housing and avoid a visible left/right jump after relayout.
    static let landscapeMinimumHorizontalMargin: Double = 64
    /// Extra whitespace between the text and a sensor/home-indicator inset.
    static let safeAreaGutter: Double = 12
    /// Longest comfortable line, in multiples of the reading font size —
    /// roughly 70 characters. Past that the eye loses its place travelling
    /// back to the next line's start, which an iPad (or a landscape phone)
    /// would otherwise force: the column takes the whole width. Surplus
    /// width becomes margin instead of measure.
    static let maximumMeasureEm: Double = 34
    /// Below this the page is too narrow for two facing columns to each
    /// hold a readable measure, so the spread setting is ignored. An iPad
    /// mini in landscape (1024pt) is the smallest screen that qualifies;
    /// the widest phone in landscape (932pt) stays single-column.
    static let spreadMinimumWidth: Double = 1000

    /// Facing columns per page: two on a wide screen in paged flow, like an
    /// open book. Everything else reads one column at a time.
    static func columnsPerPage(
        settings: ReaderSettings, pageWidth: Double
    ) -> Int {
        guard settings.pageFlow == .paged,
              settings.twoPageSpread,
              pageWidth >= spreadMinimumWidth else { return 1 }
        return 2
    }

    /// Memoised base64 `data:` URIs for bundled fonts, keyed by resource
    /// name. The WKWebView runs out-of-process and does not inherit the
    /// app's registered fonts, so the only robust way to render a custom
    /// font there is to embed its bytes inline. Encoding a ~1MB TTF on
    /// every chapter render would be wasteful, so each is encoded once.
    private static var fontFaceCache: [String: String] = [:]

    /// An `@font-face` rule embedding the given bundled font as a base64
    /// `data:` URI, or an empty string for system fonts (no embed) and
    /// when the resource is missing or unreadable — in which case the
    /// `cssFamily` fallback stack (Georgia, serif) takes over rather than
    /// the reader crashing or rendering nothing.
    static func fontFace(for font: ReaderFont) -> String {
        guard let resource = font.bundledFontFile,
              let family = font.bundledFontFamily else { return "" }

        if let cached = fontFaceCache[resource] { return cached }

        guard let url = Bundle.main.url(
                  forResource: resource, withExtension: "ttf"),
              let data = try? Data(contentsOf: url) else {
            // Missing/garbled file: skip the @font-face, keep fallbacks.
            return ""
        }

        let base64 = data.base64EncodedString()
        let rule = """
        @font-face {
            font-family: '\(family)';
            src: url(data:font/ttf;base64,\(base64)) format('truetype');
            font-weight: 100 900;
            font-style: normal;
            font-display: swap;
        }
        """
        fontFaceCache[resource] = rule
        return rule
    }

    /// The stylesheet injected into every chapter document.
    ///
    /// Paged flow lays the chapter out in viewport-wide CSS columns that
    /// overflow horizontally into the html element; turning a page
    /// scrolls html to the next column (driven from Swift via the
    /// scroll view, see ReaderController). Scroll flow leaves the
    /// document in normal vertical flow and lets the scroll view move it.
    static func css(
        settings: ReaderSettings,
        pageWidth: Double,
        pageHeight: Double,
        safeAreaLeft: Double = 0,
        safeAreaRight: Double = 0,
        systemDark: Bool = false
    ) -> String {
        let theme = settings.palette(systemDark: systemDark)
        let margin = settings.horizontalMargin
        let compactHeight = pageHeight < 500
        let minimumMargin = compactHeight
            ? max(margin, landscapeMinimumHorizontalMargin) : margin
        let baseLeftMargin = max(minimumMargin, safeAreaLeft + safeAreaGutter)
        let baseRightMargin = max(minimumMargin, safeAreaRight + safeAreaGutter)
        // Width one column gets: the whole page, or half of it in a spread.
        let columns = Double(
            columnsPerPage(settings: settings, pageWidth: pageWidth)
        )
        let columnSlot = pageWidth / columns
        // Split any width beyond a readable measure evenly into the margins.
        // Paged flow depends on column-width + column-gap == the slot, and
        // widening both margins by the same amount preserves that — so the
        // spread's inner gutter matches the outer margins, like a real book.
        let measureOverflow = max(
            0,
            (columnSlot - baseLeftMargin - baseRightMargin)
                - settings.fontSize * maximumMeasureEm
        )
        let leftMargin = baseLeftMargin + measureOverflow / 2
        let rightMargin = baseRightMargin + measureOverflow / 2
        let horizontalGutter = leftMargin + rightMargin
        let contentWidth = columnSlot - horizontalGutter
        let resolvedTopPadding = compactHeight
            ? landscapeTopPadding : topPadding
        let resolvedBottomPadding = compactHeight
            ? landscapeBottomPadding : bottomPadding
        let textHeight = pageHeight
            - resolvedTopPadding - resolvedBottomPadding

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
                padding: \(resolvedTopPadding)px \(rightMargin)px \(resolvedBottomPadding)px \(leftMargin)px !important;
                box-sizing: border-box;
                height: \(pageHeight)px !important;
                width: \(pageWidth)px !important;
                max-width: none !important;
                /* overflow must stay visible: the extra columns flow
                   past the body box into html, which scrolls them. A
                   hidden body would clip every page but the first. */
                overflow: visible !important;
                column-width: \(contentWidth)px;
                column-gap: \(horizontalGutter)px;
                column-fill: auto;
            }
            #lumen-fade {
                position: fixed;
                inset: 0;
                /* Kindle-style fade: the veil is the PAGE BACKGROUND in
                   every theme, so a turn reads as the page washing out to
                   blank paper — never a black/ink flash (that pattern only
                   makes sense on real e-paper hardware). */
                background: \(theme.backgroundHex);
                opacity: 0;
                pointer-events: none;
                /* Reveal: ease the veil away over the already-painted new
                   page — the swap happened at full opacity underneath. */
                transition: opacity 180ms ease-in-out;
                z-index: 99;
            }
            #lumen-fade.lumen-fade-on {
                /* Covering: the old page gently washes out to blank. */
                opacity: 1;
                transition: opacity 120ms ease-out;
            }
            """
        case .scroll:
            layout = """
            html {
                background: \(theme.backgroundHex) !important;
            }
            body {
                margin: 0 !important;
                padding: \(resolvedTopPadding)px \(rightMargin)px \(resolvedBottomPadding)px \(leftMargin)px !important;
                box-sizing: border-box;
                width: \(pageWidth)px !important;
                max-width: \(pageWidth)px !important;
            }
            """
        }

        // Only the selected font is embedded, so a render never carries
        // every bundled font's bytes. System fonts contribute nothing.
        let fontFaceRule = fontFace(for: settings.font)

        // Hyphenation follows justification: justified text without it
        // opens rivers of white space between words, ragged-right text
        // reads better unbroken.
        let alignment = settings.isJustified ? "justify" : "left"
        let hyphenation = settings.isJustified ? "auto" : "none"

        return """
        \(fontFaceRule)
        :root { color-scheme: \(theme.isDark ? "dark" : "light"); }
        \(layout)
        body {
            background: \(theme.backgroundHex) !important;
            color: \(theme.textHex) !important;
            font-family: \(settings.font.cssFamily) !important;
            font-size: \(settings.fontSize)px !important;
            line-height: \(settings.lineHeight) !important;
            text-rendering: optimizeLegibility;
        }
        /* Books ship their own `p { text-align: justify }`, which beats an
           unflagged rule on body however late ours is injected — so the
           reader's alignment choice only takes effect as !important.
           Headings are excluded: they keep the book's own alignment. */
        body, body p, body div, body li, body dd, body dt,
        body blockquote, body td {
            text-align: \(alignment) !important;
            -webkit-hyphens: \(hyphenation) !important;
            hyphens: \(hyphenation) !important;
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
            /* WebKit hands a drag that starts on an image to iOS's
               drag-and-drop interaction, which swallows the touch: the
               page would not scroll and the curl would not scrub while
               the finger sits on a picture. */
            -webkit-user-drag: none;
            -webkit-touch-callout: none;
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
