import SwiftUI

/// A travelling highlight sheen used by skeleton placeholders. Honours
/// Reduce Motion by collapsing to a static, faintly tinted fill so the
/// placeholder still reads as "loading" without any movement.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Colour the sheen is drawn with (usually the palette's text or
    /// secondary text, kept at a low base opacity by the caller).
    let highlight: Color

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(sheen)
                .mask(content)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.25).repeatForever(autoreverses: false)
                    ) {
                        phase = 2
                    }
                }
        }
    }

    private var sheen: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [
                    .clear,
                    highlight.opacity(0.55),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.6)
            .offset(x: phase * width)
        }
        .blendMode(.plusLighter)
    }
}

extension View {
    /// Applies a compositor-friendly shimmer sheen that respects Reduce
    /// Motion. `highlight` should already be a low-opacity palette colour.
    func shimmer(highlight: Color) -> some View {
        modifier(ShimmerModifier(highlight: highlight))
    }
}
