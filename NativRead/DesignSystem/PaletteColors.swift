import SwiftUI

/// The shared colour contract behind both palette systems: `ReaderPalette`
/// (per-book reading atmosphere) and `BrandPalette` (editorial app chrome).
///
/// Shared chrome components — loading overlays, cards, sheets — accept
/// `any PaletteColors` so they render correctly whether they sit inside the
/// reader (reading palette) or the ambient app surfaces (brand palette),
/// without conversion shims between the two.
protocol PaletteColors {
    var background: Color { get }
    var text: Color { get }
    var secondaryText: Color { get }
    var accent: Color { get }
    var surface: Color { get }
    var surfaceRaised: Color { get }
    var hairline: Color { get }
    var shadowOpacity: Double { get }
    var isDark: Bool { get }
}

// Both palette structs already expose this exact API, so conformance is free.
extension ReaderPalette: PaletteColors {}
extension BrandPalette: PaletteColors {}
