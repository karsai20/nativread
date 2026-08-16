import StoreKit
import SwiftUI

/// Every price a book can be sold at, with the length that puts it there.
///
/// A per-book price is one number out of six, and a reader who cannot see the
/// other five has no way to judge it. Showing the whole table also answers the
/// question the price alone raises — "why this much for this book?" — without
/// anyone having to ask.
///
/// Collapsed by default: it is reassurance, not the decision.
struct TranslationPriceBands: View {
    let tiers: [TranslationPricing.Tier]
    /// StoreKit products keyed by identifier. A band whose product did not load
    /// is dropped rather than shown with a made-up price.
    let products: [String: Product]
    /// The band this book falls into, so the reader can see where it sits.
    var highlightedProductID: String?
    let palette: BrandPalette

    @State private var isExpanded = false

    private var rows: [(tier: TranslationPricing.Tier, product: Product)] {
        tiers
            .sorted { $0.maxSourceCharacters < $1.maxSourceCharacters }
            .compactMap { tier in
                products[tier.productId].map { (tier, $0) }
            }
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(summary)
                            .font(Typography.meta())
                            .foregroundStyle(palette.secondaryText)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.tertiaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("translation.priceBands.toggle")

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.tier.productId) { row in
                            band(row.tier, product: row.product)
                            if row.tier.productId != rows.last?.tier.productId {
                                Divider().overlay(palette.hairline)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(palette.surface)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: Spacing.radiusCard, style: .continuous
                        )
                    )
                    .accessibilityIdentifier("translation.priceBands.list")
                }
            }
        }
    }

    /// "Books cost 2,99 € to 11,99 €, by length" — the range up front, so the
    /// collapsed state still carries the information.
    private var summary: String {
        guard let cheapest = rows.first?.product,
              let dearest = rows.last?.product
        else { return "" }
        return String(
            localized: "Books cost \(cheapest.displayPrice) to \(dearest.displayPrice), by length."
        )
    }

    private func band(
        _ tier: TranslationPricing.Tier, product: Product
    ) -> some View {
        let isHighlighted = tier.productId == highlightedProductID
        return HStack(spacing: Spacing.sm) {
            Text(verbatim: lengthText(upTo: tier.maxSourceCharacters))
                .font(Typography.meta())
                .foregroundStyle(
                    isHighlighted ? palette.text : palette.secondaryText
                )

            Spacer(minLength: Spacing.xs)

            Text(verbatim: product.displayPrice)
                .font(Typography.control(
                    14, weight: isHighlighted ? .bold : .regular
                ))
                .foregroundStyle(isHighlighted ? palette.accent : palette.text)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isSelected] : [])
    }

    /// Characters are the unit the price is actually computed from, but nobody
    /// shops in characters. Pages at 1 800 characters each — a mass-market
    /// paperback page — is the same number in a unit a reader owns.
    private func lengthText(upTo characters: Int) -> String {
        let pages = Int((Double(characters) / 1_800).rounded())
        let formatted = pages.formatted(.number.grouping(.automatic))
        return String(localized: "up to ~\(formatted) pages")
    }
}
