import SwiftUI

/// The "Aa" appearance sheet: themes, typeface, size, spacing, margins.
struct TypographyPanel: View {
    @Bindable var viewModel: ReaderViewModel

    private var settings: ReaderSettings { viewModel.settings }
    private var palette: ReaderPalette { viewModel.palette }
    private var activeTheme: ReaderTheme {
        settings.effectiveTheme(systemDark: viewModel.systemDark)
    }

    @State private var brightness = UIScreen.main.brightness
    @State private var showMore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                panelContent
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xl)
        }
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(320), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .height(320)))
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var panelContent: some View {
        Group {
            grabber

            sizeRow
                .panelCard(palette: palette)

            themeRow

            comfortSection

            moreDisclosure
        }
    }

    private var moreDisclosure: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showMore.toggle() }
            } label: {
                HStack {
                    Label("More options", systemImage: "slider.horizontal.3")
                        .font(Typography.body(15))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .rotationEffect(.degrees(showMore ? 180 : 0))
                        .foregroundStyle(palette.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .tint(palette.accent)
            .foregroundStyle(palette.text)
            .accessibilityIdentifier("panel.more")

            if showMore {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    autoThemeToggle
                    divider
                    fontList
                    divider
                    lineSpacingSlider
                    marginsSlider
                    justifiedToggle
                    divider
                    flowRow
                    if settings.pageFlow == .paged {
                        transitionRow
                    }
                }
            }
        }
    }

    private var lineSpacingSlider: some View {
        sliderRow(
            icon: "arrow.up.and.down.text.horizontal",
            label: "Line spacing",
            value: settings.lineHeight,
            range: ReaderSettings.lineHeightRange,
            step: 0.05,
            valueText: String(format: "%.2f", settings.lineHeight)
        ) { newValue in
            viewModel.updateSettings { current in
                var next = current
                next.lineHeight = newValue
                return next
            }
        }
    }

    private var marginsSlider: some View {
        sliderRow(
            icon: "rectangle.compress.vertical",
            label: "Margins",
            value: settings.horizontalMargin,
            range: ReaderSettings.marginRange,
            step: 2,
            valueText: "\(Int(settings.horizontalMargin.rounded())) pt"
        ) { newValue in
            viewModel.updateSettings { current in
                var next = current
                next.horizontalMargin = newValue
                return next
            }
        }
    }

    private var justifiedToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.isJustified },
            set: { newValue in
                viewModel.updateSettings { current in
                    var next = current
                    next.isJustified = newValue
                    return next
                }
            }
        )) {
            Label("Justified text", systemImage: "text.justify")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
    }

    // MARK: - Reading flow

    private var flowRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PageFlow.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        next.pageFlow = candidate
                        return next
                    }
                } label: {
                    Label(candidate.label, systemImage: candidate.icon)
                        .font(Typography.body(14))
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget - 6)
                }
                .segmentedWell(
                    isSelected: candidate == settings.pageFlow,
                    palette: palette
                )
                .accessibilityIdentifier("flow.\(candidate.rawValue)")
            }
        }
    }

    private var transitionRow: some View {
        HStack(spacing: Spacing.xs) {
            // Eyebrow label: tracked uppercase identifies this as a settings category.
            Label("Page turn", systemImage: "arrow.right.square")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Spacer()
            ForEach(PageTransition.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        next.pageTransition = candidate
                        return next
                    }
                } label: {
                    Text(candidate.label)
                        .font(Typography.meta(13))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs + 3)
                }
                .capsulePill(
                    isSelected: candidate == settings.pageTransition,
                    palette: palette
                )
                .accessibilityIdentifier(
                    "transition.\(candidate.rawValue)")
            }
        }
    }

    // MARK: - Eye comfort

    private var autoThemeToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.themeMode == .system },
            set: { isOn in
                viewModel.updateSettings { current in
                    var next = current
                    next.themeMode = isOn ? .system : .manual
                    return next
                }
            }
        )) {
            Label("Match system appearance",
                  systemImage: "circle.lefthalf.filled")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .accessibilityIdentifier("theme.auto")
    }

    @ViewBuilder
    private var comfortSection: some View {
        sliderRow(
            icon: "thermometer.sun",
            label: "Warm light",
            value: settings.warmth,
            range: ReaderSettings.warmthRange,
            step: 0.05,
            valueText: "\(Int((settings.warmth * 100).rounded()))%"
        ) { newValue in
            viewModel.updateSettings { current in
                var next = current
                next.warmth = newValue
                return next
            }
        }
        .accessibilityIdentifier("comfort.warmth")

        sliderRow(
            icon: "sun.max",
            label: "Brightness",
            value: brightness,
            range: 0.05...1,
            step: 0.05,
            valueText: "\(Int((brightness * 100).rounded()))%"
        ) { newValue in
            brightness = newValue
            UIScreen.main.brightness = newValue
        }
        .accessibilityIdentifier("comfort.brightness")
    }

    private var grabber: some View {
        Capsule()
            .fill(palette.secondaryText.opacity(0.4))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(palette.hairline).frame(height: 1)
    }

    // MARK: - Theme swatches

    private var themeRow: some View {
        HStack(spacing: 14) {
            ForEach(ReaderTheme.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        if current.themeMode == .system,
                           viewModel.systemDark {
                            next.darkTheme = candidate
                        } else {
                            next.theme = candidate
                        }
                        return next
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(candidate.background)
                                .overlay(
                                    Circle().strokeBorder(
                                        candidate == activeTheme
                                            ? candidate.accent
                                            : palette.text.opacity(0.15),
                                        lineWidth: candidate == activeTheme ? 2 : 1
                                    )
                                )
                                .frame(width: Spacing.minTapTarget,
                                       height: Spacing.minTapTarget)
                            Text("Aa")
                                .font(Typography.title(15))
                                .foregroundStyle(candidate.text)
                        }
                        // Meta role signals this is a caption, not a nav target.
                        Text(candidate.label)
                            .font(Typography.meta(11))
                            .foregroundStyle(
                                candidate == activeTheme
                                    ? palette.accent : palette.secondaryText
                            )
                    }
                }
                .accessibilityIdentifier("theme.\(candidate.rawValue)")
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Fonts

    private var fontList: some View {
        VStack(spacing: 0) {
            ForEach(ReaderFont.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        next.font = candidate
                        return next
                    }
                } label: {
                    HStack {
                        Text(candidate.label)
                            .font(candidate.previewFont)
                        Spacer()
                        if candidate == settings.font {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                    }
                    .padding(.vertical, 9)
                }
                .accessibilityIdentifier("font.\(candidate.rawValue)")
            }
        }
    }

    // MARK: - Size

    private var sizeRow: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                // Eyebrow label: tracked uppercase signals "settings category".
                Label("Text size", systemImage: "textformat.size")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(Int(settings.fontSize.rounded())) pt")
                    .font(Typography.meta(13))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
            }
            HStack(spacing: 0) {
                Button {
                    adjustFontSize(by: -1)
                } label: {
                    Text("A")
                        .font(Typography.title(15))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityIdentifier("fontsize.down")

                Rectangle()
                    .fill(palette.hairline)
                    .frame(width: Spacing.hairlineWidth, height: 22)

                Button {
                    adjustFontSize(by: 1)
                } label: {
                    Text("A")
                        .font(Typography.title(24))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityIdentifier("fontsize.up")
            }
            .segmentedWell(isSelected: false, palette: palette)
        }
    }

    private func adjustFontSize(by delta: Double) {
        viewModel.updateSettings { current in
            var next = current
            next.fontSize = (current.fontSize + delta)
                .clamped(to: ReaderSettings.fontSizeRange)
            return next
        }
    }

    private func sliderRow(
        icon: String,
        label: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String? = nil,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            // Eyebrow label distinguishes control categories from body copy.
            // Optional trailing readout mirrors sizeRow's numeric display.
            HStack {
                // LocalizedStringKey so the String argument still localizes.
                Label(LocalizedStringKey(label), systemImage: icon)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                if let valueText {
                    Spacer()
                    Text(valueText)
                        .font(Typography.meta(13))
                        .monospacedDigit()
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: range,
                step: step
            )
            .tint(palette.accent)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
