import Foundation
import SwiftUI

class ReaderSettings: ObservableObject {
    @AppStorage("fontSize") var fontSize: Double = 17
    @AppStorage("lineHeight") var lineHeight: Double = 1.75
    @AppStorage("marginSize") var marginSize: Double = 28
    @AppStorage("fontFamily") var fontFamily: String = FontFamily.georgia.rawValue
    @AppStorage("theme") private var themeRaw: String = ReaderTheme.light.rawValue

    var theme: ReaderTheme {
        get { ReaderTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue }
    }

    enum ReaderTheme: String, CaseIterable {
        case light = "light"
        case sepia  = "sepia"
        case dark   = "dark"

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .sepia:  return "Sepia"
            case .dark:   return "Dark"
            }
        }

        var backgroundHex: String {
            switch self {
            case .light: return "#FAFAF8"
            case .sepia:  return "#F5EDD6"
            case .dark:   return "#181818"
            }
        }

        var textHex: String {
            switch self {
            case .light: return "#1A1A1A"
            case .sepia:  return "#2B1A00"
            case .dark:   return "#E4E4DC"
            }
        }

        var linkHex: String {
            switch self {
            case .light: return "#1A1A1A"
            case .sepia:  return "#2B1A00"
            case .dark:   return "#E4E4DC"
            }
        }

        var backgroundColor: Color {
            Color(hex: backgroundHex)
        }

        var textColor: Color {
            Color(hex: textHex)
        }

        var systemColorScheme: ColorScheme? {
            switch self {
            case .dark:  return .dark
            default:     return .light
            }
        }
    }

    enum FontFamily: String, CaseIterable {
        case georgia     = "Georgia"
        case palatino    = "Palatino"
        case times       = "TimesNewRomanPSMT"
        case charter     = "Charter"
        case system      = "-apple-system"

        var displayName: String {
            switch self {
            case .georgia:  return "Georgia"
            case .palatino: return "Palatino"
            case .times:    return "Times New Roman"
            case .charter:  return "Charter"
            case .system:   return "System"
            }
        }

        var cssValue: String { rawValue }
    }

    // CSS injected into every chapter
    func generateCSS() -> String {
        let t = theme
        return """
        :root {
            --bg:          \(t.backgroundHex);
            --text:        \(t.textHex);
            --link:        \(t.linkHex);
            --font-size:   \(Int(fontSize))px;
            --line-height: \(String(format: "%.2f", lineHeight));
            --font-family: '\(fontFamily)', Georgia, 'Palatino Linotype', Palatino, serif;
            --margin-h:    \(Int(marginSize))px;
            --max-width:   660px;
        }

        *, *::before, *::after { box-sizing: border-box; }

        html { background: var(--bg); height: 100%; }

        body {
            font-family:   var(--font-family);
            font-size:     var(--font-size);
            line-height:   var(--line-height);
            color:         var(--text);
            background:    var(--bg);
            margin:        0 auto;
            padding:       56px var(--margin-h) 120px;
            max-width:     calc(var(--max-width) + var(--margin-h) * 2);
            -webkit-text-size-adjust: none;
            text-rendering: optimizeLegibility;
            -webkit-font-smoothing: antialiased;
            word-spacing:  0.02em;
        }

        h1, h2, h3, h4, h5, h6 {
            font-family: var(--font-family);
            font-weight: normal;
            line-height: 1.25;
            margin: 1.8em 0 0.6em;
            color: var(--text);
        }

        h1 { font-size: 1.55em; text-align: center; margin-top: 2.5em; }
        h2 { font-size: 1.3em; }
        h3 { font-size: 1.1em; }

        p {
            margin: 0;
            text-indent: 1.5em;
            orphans: 3;
            widows:  3;
        }

        p:first-child,
        h1 + p, h2 + p, h3 + p, h4 + p,
        blockquote + p,
        hr + p {
            text-indent: 0;
        }

        blockquote {
            margin:      1.5em 1.5em;
            padding:     0 0 0 1em;
            border-left: 2px solid rgba(128,128,128,0.35);
            font-style:  italic;
        }

        hr {
            border: none;
            text-align: center;
            margin: 2em 0;
            color: var(--text);
            opacity: 0.4;
        }

        hr::after { content: '* * *'; }

        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 1.5em auto;
        }

        a {
            color: var(--link);
            text-decoration: none;
            border-bottom: 1px solid rgba(128,128,128,0.4);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9em;
            margin: 1.5em 0;
        }

        td, th {
            padding: 0.5em 0.75em;
            border: 1px solid rgba(128,128,128,0.3);
        }

        sup, sub { font-size: 0.75em; }

        .chapter-title, [class*="chapter"] > h1:first-child {
            text-align: center;
            margin-top: 3em;
        }
        """
    }
}
