import SwiftUI

/// A stack of rounded "text line" placeholders that shimmer gently while
/// real content loads. Themed entirely by the active reader palette and
/// static under Reduce Motion. Used for the reader chapter veil and as a
/// building block for other loading states.
struct SkeletonLines: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let palette: ReaderPalette
    /// Number of placeholder lines to draw.
    var lineCount: Int = 8
    /// Relative widths (0...1) cycled across the lines so the block reads
    /// like a paragraph rather than a uniform grid.
    var widths: [CGFloat] = [1, 0.92, 0.97, 0.6, 1, 0.88, 0.95, 0.45]
    var lineHeight: CGFloat = 13
    // Spacing.md (16 pt) keeps line-gaps harmonious with the token scale.
    var spacing: CGFloat = Spacing.md

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<lineCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            palette.secondaryText
                                .opacity(reduceMotion ? 0.18 : 0.13)
                        )
                        .frame(
                            width: proxy.size.width * lineWidthFactor(index),
                            height: lineHeight
                        )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .shimmer(highlight: palette.secondaryText.opacity(0.5))
        .accessibilityHidden(true)
    }

    private func lineWidthFactor(_ index: Int) -> CGFloat {
        widths[index % widths.count]
    }
}
