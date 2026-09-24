import ImageIO
import SwiftUI

/// One book on the shelf: real cover art when the EPUB ships one,
/// otherwise a deterministic generated cover with a serif monogram.
struct BookCard: View {
    let book: Book
    let coverURL: URL?
    /// Caption colours follow the shelf's brand palette so the metadata
    /// under each cover stays in harmony with the editorial chrome.
    let titleColor: Color
    let captionColor: Color
    /// The shelf accent, used for the in-progress reading bar.
    let accentColor: Color
    /// When set, the cover is the place the translate stage lifts from.

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // The empty shape owns the 2:3 slot and the artwork fills it as an
            // overlay. Sizing the card off the cover instead lets a source
            // image that is not already 2:3 overflow the slot — the crop then
            // follows the image, not the shelf.
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { Self.cover(book: book, coverURL: coverURL) }
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .strokeBorder(.black.opacity(0.08))
                )
                .shadow(
                    color: .black.opacity(0.18), radius: 10, x: 0, y: 6
                )
                .overlay(alignment: .bottom) { progressBar }
                .overlay(alignment: .topLeading) { variantBadge }

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(Typography.control(15, weight: .bold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(book.author)
                    .font(Typography.control(13))
                    .foregroundStyle(captionColor)
                    .lineLimit(1)

                // Format and progress as one quiet meta line, the way the grid
                // reads in the redesign: identity on the left, state on the right.
                HStack {
                    Text(book.format.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                    Spacer(minLength: Spacing.xs)
                    if book.isStarted {
                        Text(
                            book.progress.bookFraction
                                .formatted(.percent.precision(.fractionLength(0)))
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                    }
                }
                .foregroundStyle(captionColor)
                .padding(.top, 1)
            }
        }
    }

    /// The cover artwork: the EPUB's own image when it ships one, otherwise a
    /// deterministic generated cover. Shared with the library's hero so both
    /// render a book identically.
    @ViewBuilder
    static func cover(book: Book, coverURL: URL?) -> some View {
        if let coverURL, let image = decodedCover(at: coverURL) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            GeneratedCover(title: book.title, author: book.author)
        }
    }

    /// Decoded once per file: re-reading a cover from disk on every render
    /// stalls the first frames of the translate lift. A cover never changes
    /// once imported, so the path is the key. Bounded by bytes, so a large
    /// shelf cannot hold every cover in memory at once.
    private static let coverCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = coverCacheBytes
        return cache
    }()

    private static let coverCacheBytes = 64 * 1024 * 1024
    /// Longest edge a cover is decoded at. The largest cover on screen (a
    /// 220 pt-wide grid card on iPad, 330 pt tall) is ~1000 px at @3x; a
    /// full-size EPUB cover decoded as-is is ~12 MB, this is ~2.7 MB.
    private static let coverMaxPixels = 1000

    private static func decodedCover(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let hit = coverCache.object(forKey: key) { return hit }
        // ImageIO downsamples while decoding, so the full-size bitmap never
        // exists — unlike scaling a decoded UIImage.
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: coverMaxPixels,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        let image = UIImage(cgImage: cgImage)
        coverCache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    @ViewBuilder
    private var progressBar: some View {
        if book.isStarted && !book.isFinished {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.35))
                    Rectangle()
                        .fill(accentColor)
                        .frame(
                            width: proxy.size.width
                                * book.progress.bookFraction
                        )
                }
            }
            .frame(height: 3)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: Spacing.radiusSmall,
                    bottomTrailingRadius: Spacing.radiusSmall
                )
            )
        } else if book.isFinished {
            HStack(spacing: 3) {
                Icon(.check, size: 8)
                Text("FINISHED")
                    .font(.system(size: 8, weight: .bold))
                    .kerning(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.55)))
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var variantBadge: some View {
        if let badge = book.variantBadgeText {
            Text(badge)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.68)))
                .padding(6)
        }
    }
}

/// Deterministic faux-cover: a duotone gradient picked from the title
/// hash, an oversized serif initial, then title and author set small.
struct GeneratedCover: View {
    let title: String
    let author: String

    private static let palettes: [(String, String, String)] = [
        ("#1F3A33", "#0E1F1B", "#D9C8A7"),
        ("#5A2A27", "#2E1413", "#E8D5B5"),
        ("#27354F", "#131B2C", "#CBD5E8"),
        ("#4F3A1E", "#2A1F0F", "#EADFC8"),
        ("#3C2B45", "#1E1525", "#D8CBE3"),
        ("#2C4248", "#142226", "#C5DBD8")
    ]

    private var palette: (Color, Color, Color) { Self.palette(for: title) }

    /// The deterministic (top, bottom, ink) triple for a title. Exposed so
    /// coverless books can still tint a row with their own artwork colours.
    static func palette(for title: String) -> (Color, Color, Color) {
        var hash = 5381
        for scalar in title.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        let chosen = palettes[abs(hash) % palettes.count]
        return (
            Color(hex: chosen.0), Color(hex: chosen.1), Color(hex: chosen.2)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let (top, bottom, ink) = palette
            ZStack {
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 0) {
                    Spacer()
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(
                            size: proxy.size.width * 0.52,
                            weight: .medium, design: .serif
                        ))
                        .italic()
                        .foregroundStyle(ink.opacity(0.92))
                    Spacer()
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(ink.opacity(0.5))
                            .frame(width: proxy.size.width * 0.3, height: 1)
                        Text(title)
                            .font(.system(
                                size: proxy.size.width * 0.072,
                                weight: .semibold, design: .serif
                            ))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(author.uppercased())
                            .font(.system(
                                size: proxy.size.width * 0.05,
                                weight: .medium
                            ))
                            .kerning(1)
                            .opacity(0.75)
                            .lineLimit(1)
                    }
                    .foregroundStyle(ink)
                    .padding(.horizontal, 10)
                    .padding(.bottom, proxy.size.height * 0.08)
                }
            }
        }
    }
}
