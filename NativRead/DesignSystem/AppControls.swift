import SwiftUI

/// Shared chrome controls for the app shell — the SwiftUI counterparts of the
/// mobile-redesign primitives. Metrics (heights, radii, type sizes, tracking)
/// come straight from that spec; colours come from `BrandPalette`.
///
/// These live outside the reader on purpose: the reader keeps its own serif,
/// paper-bound control language.

// MARK: - Primary action

/// The one dominant action on a screen or sheet. Full-width by default, so
/// callers constrain it rather than the other way round.
struct AppPrimaryButton: View {
    enum Tone {
        case accent, secondary, danger
    }

    let title: LocalizedStringKey
    var systemImage: String? = nil
    var tone: Tone = .accent
    var isEnabled: Bool = true
    let action: () -> Void

    let palette: BrandPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fill: Color {
        switch tone {
        case .accent: return palette.accent
        case .secondary: return palette.surfaceRaised
        case .danger: return palette.danger
        }
    }

    private var foreground: Color {
        tone == .secondary ? palette.text : .white
    }

    /// Directional glyphs describe what happens next, so they follow the label;
    /// every other icon names the thing being acted on and leads it.
    private var iconTrails: Bool {
        systemImage?.hasPrefix("arrow.") ?? false
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage, !iconTrails {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(Typography.control(17, weight: .bold))
                if let systemImage, iconTrails {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Spacing.lg)
            .background(fill)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusControl, style: .continuous)
            )
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Press feedback shared by the redesign's tappable surfaces: a small scale
/// dip plus a fade, skipped entirely under Reduce Motion.
struct PressScaleButtonStyle: ButtonStyle {
    var reduceMotion: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Circular icon button

/// A round, surface-filled control for header and toolbar actions. `isSelected`
/// switches it to the accent wash — used for toggles like bookmark or lock.
struct AppIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = Spacing.minTapTarget
    var isSelected: Bool = false
    let palette: BrandPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(isSelected ? palette.accent : palette.text)
                .frame(width: size, height: size)
                .background(isSelected ? palette.accentSoft : palette.surface)
                .clipShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Pill

/// A small status or format tag. Tones map to the palette's semantic accents
/// rather than arbitrary colours.
struct AppPill: View {
    enum Tone {
        case neutral, accent, info, note
    }

    let title: String
    var tone: Tone = .neutral
    let palette: BrandPalette

    private var colors: (fill: Color, text: Color) {
        switch tone {
        case .accent: return (palette.accentSoft, palette.accent)
        case .info:   return (palette.infoSoft, palette.info)
        case .note:   return (palette.noteSoft, palette.note)
        case .neutral: return (palette.surfaceRaised, palette.secondaryText)
        }
    }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.1)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(colors.fill)
            .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - Progress

/// A thin capsule progress track. `value` is clamped, so callers can pass raw
/// ratios without pre-validating them.
struct AppProgressTrack: View {
    let value: Double
    var tone: Color? = nil
    let palette: BrandPalette

    private var clamped: Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(palette.hairline)
                Capsule(style: .continuous)
                    .fill(tone ?? palette.accent)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 5)
        .accessibilityElement()
        .accessibilityValue(Text(clamped.formatted(.percent.precision(.fractionLength(0)))))
    }
}

// MARK: - Segmented control

/// An iOS-style segmented control drawn from tokens so it inherits the paper
/// palette instead of the system's grey.
struct AppSegmentedControl<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: LocalizedStringKey
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value
    let palette: BrandPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(Typography.control(13, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? palette.text : palette.secondaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, Spacing.xs)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(palette.surface)
                                    .shadow(
                                        color: .black.opacity(palette.shadowOpacity * 0.8),
                                        radius: 3, y: 1
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(palette.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.sm, style: .continuous))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selection)
    }
}
