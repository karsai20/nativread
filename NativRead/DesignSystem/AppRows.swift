import SwiftUI

/// Grouped list building blocks for Settings-style screens: an uppercase
/// section label above one rounded surface, with hairline-separated rows
/// carrying a tinted icon tile, a label, an optional value and a chevron.

// MARK: - Section

struct AppSettingsSection<Content: View>: View {
    let title: LocalizedStringKey?
    let palette: BrandPalette
    @ViewBuilder let content: Content

    init(
        _ title: LocalizedStringKey? = nil,
        palette: BrandPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.palette = palette
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let title {
                Text(title)
                    .font(Typography.control(13, weight: .semibold))
                    .tracking(0.35)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.leading, Spacing.md)
            }

            VStack(spacing: 0) {
                content
            }
            .background(palette.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
            )
        }
    }
}

// MARK: - Row

/// One line in an `AppSettingsSection`. A row with an `action` behaves as a
/// button and shows a chevron unless it carries its own trailing control.
struct AppSettingsRow<Trailing: View>: View {
    let systemImage: String?
    let title: LocalizedStringKey
    var value: String? = nil
    var isDestructive: Bool = false
    var hidesSeparator: Bool = false
    var action: (() -> Void)? = nil
    let palette: BrandPalette
    @ViewBuilder var trailing: Trailing

    private var hasTrailingControl: Bool { Trailing.self != EmptyView.self }

    var body: some View {
        VStack(spacing: 0) {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(RowHighlightButtonStyle(palette: palette))
            } else {
                content
            }

            if !hidesSeparator {
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: Spacing.hairlineWidth)
                    .padding(.leading, Spacing.md)
            }
        }
    }

    private var content: some View {
        AppSettingsRowLabel(
            systemImage: systemImage,
            title: title,
            value: value,
            isDestructive: isDestructive,
            showsChevron: action != nil && !hasTrailingControl,
            palette: palette,
            trailing: { trailing }
        )
    }
}

// MARK: - Navigating row

/// The same row, but pushing a destination instead of running a closure.
struct AppSettingsLink<Destination: View>: View {
    let systemImage: String?
    let title: LocalizedStringKey
    var value: String? = nil
    var hidesSeparator: Bool = false
    let palette: BrandPalette
    @ViewBuilder let destination: Destination

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                destination
            } label: {
                AppSettingsRowLabel(
                    systemImage: systemImage,
                    title: title,
                    value: value,
                    isDestructive: false,
                    showsChevron: true,
                    palette: palette,
                    trailing: { EmptyView() }
                )
            }
            .buttonStyle(RowHighlightButtonStyle(palette: palette))

            if !hidesSeparator {
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: Spacing.hairlineWidth)
                    .padding(.leading, Spacing.md)
            }
        }
    }
}

// MARK: - Shared row body

/// The visual contents of a settings row, shared by the tappable and the
/// navigating variants so the two can never drift apart.
struct AppSettingsRowLabel<Trailing: View>: View {
    let systemImage: String?
    let title: LocalizedStringKey
    let value: String?
    let isDestructive: Bool
    let showsChevron: Bool
    let palette: BrandPalette
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isDestructive ? palette.danger : palette.accent)
                    .frame(width: 30, height: 30)
                    .background(isDestructive ? palette.noteSoft : palette.accentSoft)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
            }

            Text(title)
                .font(Typography.control(16, weight: isDestructive ? .semibold : .regular))
                .foregroundStyle(isDestructive ? palette.danger : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                if let value {
                    Text(value)
                        .font(Typography.control(15))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                trailing
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.tertiaryText)
                }
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

extension AppSettingsRow where Trailing == EmptyView {
    init(
        systemImage: String? = nil,
        title: LocalizedStringKey,
        value: String? = nil,
        isDestructive: Bool = false,
        hidesSeparator: Bool = false,
        action: (() -> Void)? = nil,
        palette: BrandPalette
    ) {
        self.init(
            systemImage: systemImage,
            title: title,
            value: value,
            isDestructive: isDestructive,
            hidesSeparator: hidesSeparator,
            action: action,
            palette: palette,
            trailing: { EmptyView() }
        )
    }
}

/// Rows highlight by warming their background rather than fading, so the
/// hairlines around them stay put while a finger is down.
private struct RowHighlightButtonStyle: ButtonStyle {
    let palette: BrandPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? palette.surfaceRaised : Color.clear)
    }
}
