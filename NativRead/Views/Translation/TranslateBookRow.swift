import CoreImage
import SwiftUI
import UIKit

/// One book in the Translate tab's lists: cover, title, author and the
/// language it is going to (or came out in), on a row whose background is
/// tinted by the cover art itself.
struct TranslateBookRow: View {
    let book: Book
    let coverURL: URL?
    /// The language a translated copy came out in. `nil` for a source book:
    /// it can be translated into any target, so naming one would be a lie.
    let languageLabel: String?
    let systemImage: String
    let palette: BrandPalette
    let action: () -> Void

    @State private var tint: Color?

    private var fallbackTint: Color { GeneratedCover.palette(for: book.title).0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                BookCard.cover(book: book, coverURL: coverURL)
                    .frame(width: 46, height: 69)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .font(Typography.control(16, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(book.author)
                        .font(Typography.control(13))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    if let languageLabel {
                        Label(languageLabel, systemImage: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(palette.background.opacity(0.55))
                            .clipShape(Capsule(style: .continuous))
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(Spacing.sm)
            .background(background)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Spacing.radiusCard, style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .task(id: coverURL?.path) {
            tint = await CoverTint.load(coverURL)
        }
    }

    /// Spotify-style: the cover's colour bleeds in from the leading edge and
    /// fades out, so the row stays readable with the normal palette text.
    private var background: some View {
        let colour = tint ?? fallbackTint
        return ZStack {
            palette.surface
            LinearGradient(
                colors: [
                    colour.opacity(palette.isDark ? 0.55 : 0.40),
                    colour.opacity(palette.isDark ? 0.16 : 0.10)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

/// Average colour of a book cover, tuned to read as a tint rather than mud.
/// Cached by file path — a cover never changes once the book is imported.
@MainActor
enum CoverTint {
    private static var cache: [String: Color] = [:]

    static func load(_ url: URL?) async -> Color? {
        guard let url else { return nil }
        if let hit = cache[url.path] { return hit }
        let path = url.path
        guard let colour = await Task.detached(priority: .utility, operation: {
            averageColour(atPath: path)
        }).value else { return nil }
        cache[path] = colour
        return colour
    }

    /// One `CIAreaAverage` pass over the whole image. The raw average is
    /// usually washed out, so saturation is boosted and brightness clamped
    /// into a band that works on both the light and dark surface.
    private nonisolated static func averageColour(atPath path: String) -> Color? {
        guard let image = UIImage(contentsOfFile: path),
              let input = CIImage(image: image) else { return nil }

        let extent = CIVector(cgRect: input.extent)
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]
        ), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let raw = UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard raw.getHue(
            &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha
        ) else { return nil }

        return Color(UIColor(
            hue: hue,
            saturation: min(saturation * 1.7, 0.72),
            brightness: min(max(brightness, 0.38), 0.78),
            alpha: 1
        ))
    }
}
