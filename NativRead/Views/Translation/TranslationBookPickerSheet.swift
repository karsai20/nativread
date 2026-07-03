import SwiftUI

struct TranslationBookPickerSheet: View {
    let books: [Book]
    let coverURL: (Book) -> URL?
    let onSelect: (Book) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { book in
                    Button {
                        onSelect(book)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            BookCard.cover(book: book, coverURL: coverURL(book))
                                .frame(width: 42, height: 63)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: Spacing.radiusSmall
                                    )
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(book.title)
                                    .font(Typography.body(16))
                                    .foregroundStyle(palette.text)
                                    .lineLimit(2)
                                Text(book.author)
                                    .font(Typography.meta())
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
