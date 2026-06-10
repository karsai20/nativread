import SwiftUI

struct BookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverView
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if book.lastChapterIndex > 0 {
                ProgressView(value: book.readingProgress)
                    .tint(.primary.opacity(0.6))
                    .scaleEffect(y: 0.7, anchor: .center)
            }
        }
    }

    private var coverView: some View {
        Group {
            if let data = book.coverImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: coverSize.width, height: coverSize.height)
                    .clipped()
            } else {
                generatedCover
                    .frame(width: coverSize.width, height: coverSize.height)
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
    }

    private var coverSize: CGSize { CGSize(width: 160, height: 240) }

    private var generatedCover: some View {
        ZStack {
            LinearGradient(
                colors: coverColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Spacer()
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .lineLimit(4)

                if book.author != "Unknown Author" {
                    Text(book.author)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
                Spacer().frame(height: 14)
            }
        }
    }

    // Deterministic color pair from title hash
    private var coverColors: [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "#2C3E50"), Color(hex: "#4CA1AF")],
            [Color(hex: "#373B44"), Color(hex: "#4286f4")],
            [Color(hex: "#614385"), Color(hex: "#516395")],
            [Color(hex: "#1A2980"), Color(hex: "#26D0CE")],
            [Color(hex: "#232526"), Color(hex: "#414345")],
            [Color(hex: "#3A1C71"), Color(hex: "#D76D77")],
            [Color(hex: "#004E92"), Color(hex: "#000428")],
            [Color(hex: "#403B4A"), Color(hex: "#E7E9BB")],
        ]
        let index = abs(book.title.hashValue) % palettes.count
        return palettes[index]
    }
}
