import SwiftUI

/// Refined, hand-built controls for the "Aa" appearance sheet. The stock
/// SwiftUI `Slider`, `Toggle` row, and circular swatches read as generic;
/// these replacements carry the editorial identity (thick parchment track,
/// ringed thumb, page-like theme tiles) and feel deliberate at the point of
/// touch — closer to Apple Books than a settings form.

// MARK: - Editorial slider

/// A continuous control with a thick rounded track, an accent fill, a ringed
/// thumb that lifts off the page, and optional end glyphs (small/large "A",
/// sun, thermometer). Drag anywhere on the track; value snaps to `step` and
/// fires selection haptics as it crosses a notch.
struct EditorialSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    var leadingSymbol: String? = nil
    var trailingSymbol: String? = nil
    let palette: ReaderPalette
    let onChange: (Double) -> Void

    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 28

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let leadingSymbol {
                glyph(leadingSymbol, size: 13)
            }
            track
            if let trailingSymbol {
                glyph(trailingSymbol, size: 18)
            }
        }
        .frame(height: thumbSize)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func glyph(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(palette.secondaryText)
            .frame(width: 20)
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(((value - range.lowerBound) / span)).clampedUnit()
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let travel = max(0, width - thumbSize)
            let center = fraction * travel + thumbSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.hairline)
                    .frame(height: trackHeight)
                Capsule()
                    .fill(palette.accent)
                    .frame(width: center, height: trackHeight)
                Circle()
                    .fill(palette.surfaceRaised)
                    .overlay(Circle().strokeBorder(palette.accent, lineWidth: 2.5))
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(
                        color: .black.opacity(palette.shadowOpacity),
                        radius: 3, y: 1
                    )
                    .offset(x: center - thumbSize / 2)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard travel > 0 else { return }
                        let unit = ((gesture.location.x - thumbSize / 2) / travel)
                            .clampedUnit()
                        let raw = range.lowerBound
                            + Double(unit) * (range.upperBound - range.lowerBound)
                        let snapped = (raw / step).rounded() * step
                        let next = snapped.clamped(to: range)
                        if next != value { onChange(next) }
                    }
            )
        }
        .frame(height: thumbSize)
    }
}

/// An eyebrow caption + live readout above a control, the editorial header
/// for each slider group.
struct ControlLabel: View {
    let title: LocalizedStringKey
    let icon: String
    var value: String? = nil
    let palette: ReaderPalette

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            if let value {
                Spacer()
                Text(value)
                    .font(Typography.meta(13))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

// MARK: - Text size stepper

/// The most-used control: a wide card with a small-"A" decrement, a live
/// "Aa" specimen at the current size, and a large-"A" increment. Buttons
/// flash the accent on press; the specimen scales with the chosen size so
/// the effect is legible before leaving the sheet.
struct SizeStepper: View {
    let size: Double
    let range: ClosedRange<Double>
    let palette: ReaderPalette
    let onStep: (Double) -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton(symbolSize: 16, delta: -1, id: "fontsize.down")
            divider
            specimen
            divider
            stepButton(symbolSize: 27, delta: 1, id: "fontsize.up")
        }
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusCard)
                .fill(palette.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusCard)
                .strokeBorder(palette.hairline)
        )
    }

    private var specimen: some View {
        VStack(spacing: 1) {
            Text("Aa")
                .font(.custom(Typography.displayFamily, size: clampedSpecimen))
                .foregroundStyle(palette.text)
            Text("\(Int(size.rounded())) pt")
                .font(Typography.meta(11))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    /// Keep the specimen within the 60pt card while still tracking the size.
    private var clampedSpecimen: CGFloat {
        CGFloat(min(size + 8, 34))
    }

    private func stepButton(
        symbolSize: CGFloat, delta: Double, id: String
    ) -> some View {
        Button {
            onStep(delta)
        } label: {
            Text("A")
                .font(.custom(Typography.displayFamily, size: symbolSize))
                .foregroundStyle(canStep(delta) ? palette.text : palette.secondaryText.opacity(0.4))
                .frame(width: 64)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressHighlightStyle(palette: palette))
        .disabled(!canStep(delta))
        .accessibilityIdentifier(id)
    }

    private func canStep(_ delta: Double) -> Bool {
        let next = size + delta
        return next >= range.lowerBound && next <= range.upperBound
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(width: Spacing.hairlineWidth, height: 28)
    }
}

/// Flashes an accent wash while a control is held — gives the stepper and
/// theme tiles a tactile, "designed" press state instead of the flat default.
struct PressHighlightStyle: ButtonStyle {
    let palette: ReaderPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? palette.accent.opacity(ReaderControlStyle.selectedAccentOpacity)
                    : Color.clear
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Theme tile

/// A page-like rounded tile previewing a reading theme: the real background,
/// an "Aa" in the theme's ink, and the theme name. Selected tiles gain an
/// accent ring and lift; the whole tile is the tap target.
struct ThemeTile: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let palette: ReaderPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .fill(theme.background)
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .strokeBorder(
                            isSelected ? theme.accent : palette.hairline,
                            lineWidth: isSelected ? 2.5 : 1
                        )
                    Text("Aa")
                        .font(.custom(Typography.displayFamily, size: 24))
                        .foregroundStyle(theme.text)
                }
                .frame(height: 58)
                .shadow(
                    color: .black.opacity(isSelected ? palette.shadowOpacity : 0),
                    radius: 5, y: 2
                )

                Text(theme.label)
                    .font(Typography.meta(11))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme.\(theme.rawValue)")
    }
}

// MARK: - Segmented tabs

/// The three calm sections of the appearance sheet. Tabs keep every control
/// one tap away — no "More options" disclosure, no long scroll — so each
/// surface stays uncrowded. This is the custom pattern NativRead uses instead of
/// Apple Books' single scrolling list.
enum AppearanceTab: String, CaseIterable, Identifiable {
    case theme, text, layout
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .theme:  return "Theme"
        case .text:   return "Text"
        case .layout: return "Layout"
        }
    }

    var icon: String {
        switch self {
        case .theme:  return "circle.lefthalf.filled"
        case .text:   return "textformat"
        case .layout: return "rectangle.portrait.arrowtriangle.2.inward"
        }
    }
}

/// An editorial segmented control: a recessed well with a single raised pill
/// that slides to the active tab. Selected text takes the accent; the pill
/// lifts on a soft shadow.
struct SegmentedTabs: View {
    @Binding var selection: AppearanceTab
    let palette: ReaderPalette
    @Namespace private var pill

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(AppearanceTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.snappy(duration: 0.28)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.label)
                            .font(Typography.body(15))
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Spacing.radiusSmall - 2)
                                .fill(palette.surfaceRaised)
                                .matchedGeometryEffect(id: "pill", in: pill)
                                .shadow(
                                    color: .black.opacity(palette.shadowOpacity * 0.6),
                                    radius: 3, y: 1
                                )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("appearance.tab.\(tab.rawValue)")
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                .fill(palette.surface)
        )
    }
}

// MARK: - Numeric helpers

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension CGFloat {
    /// Clamp to 0...1 for fractional track positions.
    func clampedUnit() -> CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}
