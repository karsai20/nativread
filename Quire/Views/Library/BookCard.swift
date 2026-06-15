import SwiftUI

/// One book on the shelf: real cover art when the EPUB ships one,
/// otherwise a deterministic generated cover with a serif monogram.
struct BookCard: View {
    let book: Book
    let coverURL: URL?
    /// Caption colours follow the active reading theme so the metadata
    /// under each cover stays in harmony with the shelf chrome.
    let titleColor: Color
    let captionColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.black.opacity(0.08))
                )
                .shadow(
                    color: .black.opacity(0.18), radius: 10, x: 0, y: 6
                )
                .overlay(alignment: .bottom) { progressBar }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold,
                                  design: .serif))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(captionColor)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let coverURL,
           let image = UIImage(contentsOfFile: coverURL.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            GeneratedCover(title: book.title, author: book.author)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if book.isStarted && !book.isFinished {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.35))
                    Rectangle()
                        .fill(Color(hex: "#E8B04B"))
                        .frame(
                            width: proxy.size.width
                                * book.progress.bookFraction
                        )
                }
            }
            .frame(height: 3)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 6, bottomTrailingRadius: 6
                )
            )
        } else if book.isFinished {
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
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

    private var palette: (Color, Color, Color) {
        var hash = 5381
        for scalar in title.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        let chosen = Self.palettes[abs(hash) % Self.palettes.count]
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
