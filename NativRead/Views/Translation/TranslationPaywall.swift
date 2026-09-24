import SwiftUI

/// The step between seeing the price and paying it: what the reader gets, the
/// price once more, one button. The book is uploaded only after this purchase
/// goes through, and the sheet says so.
struct TranslationPaywall: View {
    let book: Book
    let languageName: String
    let price: String
    let readyIn: String?
    let isBeta: Bool
    let isPaying: Bool
    let message: String?
    let palette: BrandPalette
    let onBuy: () -> Void
    let onTerms: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppSheetHeader(
                title: "Translate the whole book",
                onDone: isPaying ? nil : { dismiss() },
                palette: palette
            )

            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: book.title)
                        .font(.custom(Typography.displayFamily, size: 24))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    Text(verbatim: book.author)
                        .font(Typography.meta(14))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    benefit(.bookOpen, Text("Every chapter, in \(languageName)"))
                    benefit(.check, Text("Yours for good. No subscription"))
                    benefit(.lock, Text("Your book is uploaded only after you pay"))
                    if let readyIn {
                        benefit(.hourglass, Text("Ready in \(readyIn)"))
                    }
                }

                if isBeta {
                    Text("Beta: this language is still being quality-checked.")
                        .font(Typography.meta(12))
                        .foregroundStyle(palette.note)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.md)

            Spacer(minLength: Spacing.lg)

            VStack(spacing: Spacing.sm) {
                VStack(spacing: 2) {
                    Text(verbatim: price)
                        .font(Typography.control(28, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.text)
                    Text("One-time purchase")
                        .font(Typography.meta(13))
                        .foregroundStyle(palette.secondaryText)
                }
                .accessibilityElement(children: .combine)

                TranslateCapsule(
                    title: String(localized: isPaying ? "Processing…" : "Buy", bundle: .appLanguage),
                    price: nil,
                    progress: nil,
                    isEnabled: !isPaying,
                    palette: palette,
                    action: onBuy
                )
                .accessibilityIdentifier("translation.paywall.buy")

                if let message {
                    Text(verbatim: message)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TranslationFinePrint(palette: palette, onTerms: onTerms)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled(isPaying)
        .accessibilityIdentifier("translation.paywall")
    }

    private func benefit(_ icon: LucideIcon, _ text: Text) -> some View {
        HStack(spacing: Spacing.sm) {
            Icon(icon, size: 18)
                .foregroundStyle(palette.accent)
                .frame(width: 24)
            text
                .font(Typography.control(15, weight: .medium))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
