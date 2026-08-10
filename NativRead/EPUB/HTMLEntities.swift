import Foundation

/// Decodes HTML character references the same way the translation backend does
/// (`node-html-parser` → `he.decode`), so an on-device price quote counts the
/// same characters as the server-side one.
///
/// ponytail: the XHTML 1.0 entity set (Latin-1 + symbols + special, plus
/// `apos`) and numeric references only. `he` also knows all 2231 HTML5 names
/// and decodes ~106 of them without a trailing semicolon — neither is
/// well-formed XML, which is what an EPUB content document has to be. Extend
/// `named` if a real book ever proves otherwise.
enum HTMLEntities {

    /// Replaces every `&name;`, `&#123;` and `&#x1F;` reference in `text`.
    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var output = ""
        output.reserveCapacity(text.count)
        var cursor = text.startIndex
        while let ampersand = text[cursor...].firstIndex(of: "&") {
            output += text[cursor..<ampersand]
            let (replacement, next) = reference(in: text, at: ampersand)
            output += replacement ?? "&"
            cursor = next
        }
        output += text[cursor...]
        return output
    }

    // MARK: - Reference parsing

    /// Reads the reference starting at `start` (which holds the `&`).
    /// Returns its replacement — nil when the `&` starts no valid reference —
    /// and the index to resume scanning from.
    private static func reference(
        in text: String, at start: String.Index
    ) -> (replacement: String?, next: String.Index) {
        let afterAmpersand = text.index(after: start)
        let unresolved = (replacement: String?.none, next: afterAmpersand)
        guard afterAmpersand < text.endIndex else { return unresolved }

        guard text[afterAmpersand] == "#" else {
            var end = afterAmpersand
            while end < text.endIndex, text[end].isASCIILetterOrDigit {
                end = text.index(after: end)
            }
            guard end > afterAmpersand, end < text.endIndex, text[end] == ";",
                  let value = named[String(text[afterAmpersand..<end])]
            else { return unresolved }
            return (value, text.index(after: end))
        }

        var digits = text.index(after: afterAmpersand)
        let isHex = digits < text.endIndex && (text[digits] == "x" || text[digits] == "X")
        if isHex { digits = text.index(after: digits) }
        var end = digits
        while end < text.endIndex, isHex ? text[end].isASCIIHexDigit : text[end].isASCIIDigit {
            end = text.index(after: end)
        }
        guard end > digits else { return unresolved }
        // A trailing semicolon is optional here, exactly as in `he`.
        let next = end < text.endIndex && text[end] == ";" ? text.index(after: end) : end
        return (symbol(forCodePoint: String(text[digits..<end]), isHex: isHex), next)
    }

    /// `he`'s `codePointToSymbol`: surrogates and out-of-range values become
    /// U+FFFD, and the Windows-1252 range is remapped as the HTML spec demands.
    private static func symbol(forCodePoint digits: String, isHex: Bool) -> String {
        guard let value = UInt32(digits, radix: isHex ? 16 : 10) else { return "\u{FFFD}" }
        if let override = numericOverrides[value] { return override }
        guard !(0xD800...0xDFFF).contains(value), let scalar = Unicode.Scalar(value) else {
            return "\u{FFFD}"
        }
        return String(scalar)
    }

    private static let numericOverrides: [UInt32: String] = [
        0x00: "\u{FFFD}", 128: "\u{20AC}", 130: "\u{201A}", 131: "\u{192}",
        132: "\u{201E}", 133: "\u{2026}", 134: "\u{2020}", 135: "\u{2021}",
        136: "\u{2C6}", 137: "\u{2030}", 138: "\u{160}", 139: "\u{2039}",
        140: "\u{152}", 142: "\u{17D}", 145: "\u{2018}", 146: "\u{2019}",
        147: "\u{201C}", 148: "\u{201D}", 149: "\u{2022}", 150: "\u{2013}",
        151: "\u{2014}", 152: "\u{2DC}", 153: "\u{2122}", 154: "\u{161}",
        155: "\u{203A}", 156: "\u{153}", 158: "\u{17E}", 159: "\u{178}",
    ]

    /// XHTML 1.0 Latin-1, symbol and special entity sets, plus `apos`.
    private static let named: [String: String] = [
    "nbsp": "\u{A0}",
    "iexcl": "\u{A1}",
    "cent": "\u{A2}",
    "pound": "\u{A3}",
    "curren": "\u{A4}",
    "yen": "\u{A5}",
    "brvbar": "\u{A6}",
    "sect": "\u{A7}",
    "uml": "\u{A8}",
    "copy": "\u{A9}",
    "ordf": "\u{AA}",
    "laquo": "\u{AB}",
    "not": "\u{AC}",
    "shy": "\u{AD}",
    "reg": "\u{AE}",
    "macr": "\u{AF}",
    "deg": "\u{B0}",
    "plusmn": "\u{B1}",
    "sup2": "\u{B2}",
    "sup3": "\u{B3}",
    "acute": "\u{B4}",
    "micro": "\u{B5}",
    "para": "\u{B6}",
    "middot": "\u{B7}",
    "cedil": "\u{B8}",
    "sup1": "\u{B9}",
    "ordm": "\u{BA}",
    "raquo": "\u{BB}",
    "frac14": "\u{BC}",
    "frac12": "\u{BD}",
    "frac34": "\u{BE}",
    "iquest": "\u{BF}",
    "Agrave": "\u{C0}",
    "Aacute": "\u{C1}",
    "Acirc": "\u{C2}",
    "Atilde": "\u{C3}",
    "Auml": "\u{C4}",
    "Aring": "\u{C5}",
    "AElig": "\u{C6}",
    "Ccedil": "\u{C7}",
    "Egrave": "\u{C8}",
    "Eacute": "\u{C9}",
    "Ecirc": "\u{CA}",
    "Euml": "\u{CB}",
    "Igrave": "\u{CC}",
    "Iacute": "\u{CD}",
    "Icirc": "\u{CE}",
    "Iuml": "\u{CF}",
    "ETH": "\u{D0}",
    "Ntilde": "\u{D1}",
    "Ograve": "\u{D2}",
    "Oacute": "\u{D3}",
    "Ocirc": "\u{D4}",
    "Otilde": "\u{D5}",
    "Ouml": "\u{D6}",
    "times": "\u{D7}",
    "Oslash": "\u{D8}",
    "Ugrave": "\u{D9}",
    "Uacute": "\u{DA}",
    "Ucirc": "\u{DB}",
    "Uuml": "\u{DC}",
    "Yacute": "\u{DD}",
    "THORN": "\u{DE}",
    "szlig": "\u{DF}",
    "agrave": "\u{E0}",
    "aacute": "\u{E1}",
    "acirc": "\u{E2}",
    "atilde": "\u{E3}",
    "auml": "\u{E4}",
    "aring": "\u{E5}",
    "aelig": "\u{E6}",
    "ccedil": "\u{E7}",
    "egrave": "\u{E8}",
    "eacute": "\u{E9}",
    "ecirc": "\u{EA}",
    "euml": "\u{EB}",
    "igrave": "\u{EC}",
    "iacute": "\u{ED}",
    "icirc": "\u{EE}",
    "iuml": "\u{EF}",
    "eth": "\u{F0}",
    "ntilde": "\u{F1}",
    "ograve": "\u{F2}",
    "oacute": "\u{F3}",
    "ocirc": "\u{F4}",
    "otilde": "\u{F5}",
    "ouml": "\u{F6}",
    "divide": "\u{F7}",
    "oslash": "\u{F8}",
    "ugrave": "\u{F9}",
    "uacute": "\u{FA}",
    "ucirc": "\u{FB}",
    "uuml": "\u{FC}",
    "yacute": "\u{FD}",
    "thorn": "\u{FE}",
    "yuml": "\u{FF}",
    "fnof": "\u{192}",
    "Alpha": "\u{391}",
    "Beta": "\u{392}",
    "Gamma": "\u{393}",
    "Delta": "\u{394}",
    "Epsilon": "\u{395}",
    "Zeta": "\u{396}",
    "Eta": "\u{397}",
    "Theta": "\u{398}",
    "Iota": "\u{399}",
    "Kappa": "\u{39A}",
    "Lambda": "\u{39B}",
    "Mu": "\u{39C}",
    "Nu": "\u{39D}",
    "Xi": "\u{39E}",
    "Omicron": "\u{39F}",
    "Pi": "\u{3A0}",
    "Rho": "\u{3A1}",
    "Sigma": "\u{3A3}",
    "Tau": "\u{3A4}",
    "Upsilon": "\u{3A5}",
    "Phi": "\u{3A6}",
    "Chi": "\u{3A7}",
    "Psi": "\u{3A8}",
    "Omega": "\u{3A9}",
    "alpha": "\u{3B1}",
    "beta": "\u{3B2}",
    "gamma": "\u{3B3}",
    "delta": "\u{3B4}",
    "epsilon": "\u{3B5}",
    "zeta": "\u{3B6}",
    "eta": "\u{3B7}",
    "theta": "\u{3B8}",
    "iota": "\u{3B9}",
    "kappa": "\u{3BA}",
    "lambda": "\u{3BB}",
    "mu": "\u{3BC}",
    "nu": "\u{3BD}",
    "xi": "\u{3BE}",
    "omicron": "\u{3BF}",
    "pi": "\u{3C0}",
    "rho": "\u{3C1}",
    "sigma": "\u{3C3}",
    "sigmaf": "\u{3C2}",
    "tau": "\u{3C4}",
    "upsilon": "\u{3C5}",
    "phi": "\u{3C6}",
    "chi": "\u{3C7}",
    "psi": "\u{3C8}",
    "omega": "\u{3C9}",
    "thetasym": "\u{3D1}",
    "upsih": "\u{3D2}",
    "piv": "\u{3D6}",
    "bull": "\u{2022}",
    "hellip": "\u{2026}",
    "prime": "\u{2032}",
    "Prime": "\u{2033}",
    "oline": "\u{203E}",
    "frasl": "\u{2044}",
    "weierp": "\u{2118}",
    "image": "\u{2111}",
    "real": "\u{211C}",
    "trade": "\u{2122}",
    "alefsym": "\u{2135}",
    "larr": "\u{2190}",
    "uarr": "\u{2191}",
    "rarr": "\u{2192}",
    "darr": "\u{2193}",
    "harr": "\u{2194}",
    "crarr": "\u{21B5}",
    "lArr": "\u{21D0}",
    "uArr": "\u{21D1}",
    "rArr": "\u{21D2}",
    "dArr": "\u{21D3}",
    "hArr": "\u{21D4}",
    "forall": "\u{2200}",
    "part": "\u{2202}",
    "exist": "\u{2203}",
    "empty": "\u{2205}",
    "nabla": "\u{2207}",
    "isin": "\u{2208}",
    "notin": "\u{2209}",
    "ni": "\u{220B}",
    "prod": "\u{220F}",
    "sum": "\u{2211}",
    "minus": "\u{2212}",
    "lowast": "\u{2217}",
    "radic": "\u{221A}",
    "prop": "\u{221D}",
    "infin": "\u{221E}",
    "ang": "\u{2220}",
    "and": "\u{2227}",
    "or": "\u{2228}",
    "cap": "\u{2229}",
    "cup": "\u{222A}",
    "int": "\u{222B}",
    "there4": "\u{2234}",
    "sim": "\u{223C}",
    "cong": "\u{2245}",
    "asymp": "\u{2248}",
    "ne": "\u{2260}",
    "equiv": "\u{2261}",
    "le": "\u{2264}",
    "ge": "\u{2265}",
    "sub": "\u{2282}",
    "sup": "\u{2283}",
    "nsub": "\u{2284}",
    "sube": "\u{2286}",
    "supe": "\u{2287}",
    "oplus": "\u{2295}",
    "otimes": "\u{2297}",
    "perp": "\u{22A5}",
    "sdot": "\u{22C5}",
    "lceil": "\u{2308}",
    "rceil": "\u{2309}",
    "lfloor": "\u{230A}",
    "rfloor": "\u{230B}",
    "lang": "\u{27E8}",
    "rang": "\u{27E9}",
    "loz": "\u{25CA}",
    "spades": "\u{2660}",
    "clubs": "\u{2663}",
    "hearts": "\u{2665}",
    "diams": "\u{2666}",
    "quot": "\u{22}",
    "amp": "\u{26}",
    "lt": "\u{3C}",
    "gt": "\u{3E}",
    "OElig": "\u{152}",
    "oelig": "\u{153}",
    "Scaron": "\u{160}",
    "scaron": "\u{161}",
    "Yuml": "\u{178}",
    "circ": "\u{2C6}",
    "tilde": "\u{2DC}",
    "ensp": "\u{2002}",
    "emsp": "\u{2003}",
    "thinsp": "\u{2009}",
    "zwnj": "\u{200C}",
    "zwj": "\u{200D}",
    "lrm": "\u{200E}",
    "rlm": "\u{200F}",
    "ndash": "\u{2013}",
    "mdash": "\u{2014}",
    "lsquo": "\u{2018}",
    "rsquo": "\u{2019}",
    "sbquo": "\u{201A}",
    "ldquo": "\u{201C}",
    "rdquo": "\u{201D}",
    "bdquo": "\u{201E}",
    "dagger": "\u{2020}",
    "Dagger": "\u{2021}",
    "permil": "\u{2030}",
    "lsaquo": "\u{2039}",
    "rsaquo": "\u{203A}",
    "euro": "\u{20AC}",
    "apos": "\u{27}",    ]
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIIHexDigit: Bool { isASCII && isHexDigit }
    var isASCIILetterOrDigit: Bool { isASCII && (isLetter || isNumber) }
}
