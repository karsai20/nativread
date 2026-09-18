import SwiftUI

/// The "Aa" appearance sheet: one scrolling panel in four eyebrow-labelled
/// sections — Atmosphere, Text, Layout, Comfort — with no tabs. The theme
/// tiles set "Aa" in the reader's own typeface; every control repaints the
/// page underneath as it changes.
struct TypographyPanel: View {
    @Bindable var viewModel: ReaderViewModel

    private var settings: ReaderSettings { viewModel.settings }
    private var palette: ReaderPalette { viewModel.palette }
    private var activeTheme: ReaderTheme {
        settings.effectiveTheme(systemDark: viewModel.systemDark)
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var brightness = UIScreen.main.brightness
    /// The typeface list is long; it folds under its row until asked for.
    @State private var isTypefaceListExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            grabber
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    section("appearance.section.atmosphere") {
                        themeGrid
                        autoThemeToggle
                    }
                    divider
                    section("appearance.section.text") {
                        sizeGroup
                        typefaceRow
                        lineSpacingGroup
                        justifiedToggle
                    }
                    divider
                    section("appearance.section.layout") {
                        marginsGroup
                        flowGroup
                        if settings.pageFlow == .paged {
                            transitionRow
                            // Without this row the picker above looks broken: iOS is
                            // quietly overriding it and nothing on screen said so.
                            if reduceMotion { reduceMotionRow }
                            // Only a regular-width device can ever show two columns.
                            if horizontalSizeClass == .regular { spreadToggle }
                        }
                    }
                    divider
                    section("appearance.section.comfort") {
                        warmthGroup
                        brightnessGroup
                    }
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.lg)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: settings.pageFlow)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: isTypefaceListExpanded)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(450), .large])
        // ponytail: no presentationBackgroundInteraction — enabling it up
        // through the small detent makes iOS treat the sheet as a non-modal
        // accessory and kills swipe/flick-to-dismiss. Plain modal sheet =
        // standard flick-down dismissal.
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.hidden)
    }

    /// An eyebrow-labelled group: the panel's only structural device, so
    /// the reader can skim to a section without a mode switch.
    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            content()
        }
    }

    // MARK: - Theme tiles

    private var themeGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4),
            spacing: Spacing.sm
        ) {
            ForEach(ReaderTheme.allCases) { candidate in
                ThemeTile(
                    theme: candidate,
                    isSelected: candidate == activeTheme,
                    font: settings.font,
                    palette: palette
                ) {
                    selectTheme(candidate)
                }
            }
        }
    }

    private func selectTheme(_ candidate: ReaderTheme) {
        viewModel.updateSettings { current in
            var next = current
            if current.themeMode == .system, viewModel.systemDark {
                next.darkTheme = candidate
            } else {
                next.theme = candidate
            }
            return next
        }
    }

    // MARK: - Text size

    private var sizeGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ControlLabel(
                title: "Text size",
                icon: .aLargeSmall,
                palette: palette
            )
            SizeStepper(
                size: settings.fontSize,
                range: ReaderSettings.fontSizeRange,
                palette: palette,
                onStep: adjustFontSize
            )
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

    // MARK: - Brightness

    private var brightnessGroup: some View {
        sliderGroup(
            title: "Brightness",
            icon: .sun,
            valueText: "\(Int((brightness * 100).rounded()))%",
            value: brightness,
            range: 0.05...1,
            step: 0.05,
            leadingIcon: .sunDim,
            trailingIcon: .sun
        ) { newValue in
            brightness = newValue
            UIScreen.main.brightness = newValue
        }
        .accessibilityIdentifier("comfort.brightness")
    }

    // MARK: - Fine-tuning sliders

    private var warmthGroup: some View {
        sliderGroup(
            title: "Warm light",
            icon: .thermometerSun,
            valueText: "\(Int((settings.warmth * 100).rounded()))%",
            value: settings.warmth,
            range: ReaderSettings.warmthRange,
            step: 0.05,
            leadingIcon: .moon,
            trailingIcon: .thermometerSun
        ) { newValue in
            updateSettings { $0.warmth = newValue }
        }
        .accessibilityIdentifier("comfort.warmth")
    }

    private var lineSpacingGroup: some View {
        sliderGroup(
            title: "Line spacing",
            icon: .unfoldVertical,
            valueText: String(format: "%.2f", settings.lineHeight),
            value: settings.lineHeight,
            range: ReaderSettings.lineHeightRange,
            step: 0.05,
            leadingIcon: .alignLeft,
            trailingIcon: .alignJustify
        ) { newValue in
            updateSettings { $0.lineHeight = newValue }
        }
    }

    private var marginsGroup: some View {
        sliderGroup(
            title: "Margins",
            icon: .foldVertical,
            valueText: "\(Int(settings.horizontalMargin.rounded())) pt",
            value: settings.horizontalMargin,
            range: ReaderSettings.marginRange,
            step: 2,
            leadingIcon: .foldVertical,
            trailingIcon: .unfoldVertical
        ) { newValue in
            updateSettings { $0.horizontalMargin = newValue }
        }
    }

    // MARK: - Toggles

    private var justifiedToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.isJustified },
            set: { newValue in updateSettings { $0.isJustified = newValue } }
        )) {
            Label { Text("Justified text") } icon: { Icon(.alignJustify, size: 16) }
                .font(Typography.body(15))
        }
        .tint(palette.accent)
    }

    private var spreadToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.twoPageSpread },
            set: { newValue in updateSettings { $0.twoPageSpread = newValue } }
        )) {
            Label { Text("Two pages in landscape") } icon: { Icon(.book, size: 16) }
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .accessibilityIdentifier("layout.spread")
    }

    /// Shown only while iOS Reduce Motion is on, where it explains why the
    /// page-turn picker has no effect and offers the way back.
    private var reduceMotionRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Toggle(isOn: Binding(
                get: { settings.allowsMotionWhenReduced },
                set: { newValue in
                    updateSettings { $0.allowsMotionWhenReduced = newValue }
                }
            )) {
                Label {
                    Text("Animate page turns anyway")
                } icon: {
                    Icon(.accessibility, size: 16)
                }
                    .font(Typography.body(15))
            }
            .tint(palette.accent)
            .accessibilityIdentifier("layout.allowsMotion")

            Text("Reduce Motion is on in iOS Settings, so page turns are instant.")
                .font(Typography.meta(12))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var autoThemeToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.themeMode == .system },
            set: { isOn in
                updateSettings { $0.themeMode = isOn ? .system : .manual }
            }
        )) {
            Label {
                Text("Match system appearance")
            } icon: {
                Icon(.contrast, size: 16)
            }
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .accessibilityIdentifier("theme.auto")
    }

    // MARK: - Reading flow

    private var flowGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ControlLabel(title: "Page flow", icon: .bookOpen, palette: palette)
            flowRow
        }
    }

    private var flowRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PageFlow.allCases) { candidate in
                Button {
                    updateSettings { $0.pageFlow = candidate }
                } label: {
                    Label { Text(candidate.label) } icon: { Icon(candidate.icon, size: 14) }
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
        // Four options no longer fit beside the eyebrow label; stack them
        // under it like flowGroup, pills sharing the width equally.
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                Text("Page turn")
            } icon: {
                Icon(.squareArrowRight, size: 13)
            }
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            HStack(spacing: Spacing.xs) {
                ForEach(PageTransition.allCases) { candidate in
                    Button {
                        updateSettings { $0.pageTransition = candidate }
                    } label: {
                        Text(candidate.label)
                            .font(Typography.meta(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, Spacing.xxs)
                            .padding(.vertical, Spacing.xxs + 3)
                            .frame(maxWidth: .infinity)
                    }
                    .capsulePill(
                        isSelected: candidate == settings.pageTransition,
                        palette: palette
                    )
                    .accessibilityIdentifier("transition.\(candidate.rawValue)")
                }
            }
        }
    }

    // MARK: - Typeface (collapsible)

    private var typefaceRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isTypefaceListExpanded.toggle()
            } label: {
                HStack {
                    ControlLabel(title: "appearance.typeface", icon: .type, palette: palette)
                    Spacer()
                    Text(settings.font.label)
                        .font(settings.font.previewFont(size: 15))
                        .foregroundStyle(palette.text)
                    Icon(.chevronDown, size: 12)
                        .foregroundStyle(palette.secondaryText)
                        .rotationEffect(.degrees(isTypefaceListExpanded ? 180 : 0))
                }
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("appearance.typeface")
            .accessibilityValue(settings.font.label)

            if isTypefaceListExpanded {
                fontList
                    .padding(.leading, Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Fonts

    private var fontList: some View {
        VStack(spacing: 0) {
            ForEach(ReaderFont.allCases) { candidate in
                Button {
                    updateSettings { $0.font = candidate }
                } label: {
                    HStack {
                        Text(candidate.label)
                            .font(candidate.previewFont())
                        Spacer()
                        if candidate == settings.font {
                            Icon(.check, size: 13)
                                .foregroundStyle(palette.accent)
                        }
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("font.\(candidate.rawValue)")
            }
        }
    }

    // MARK: - Chrome

    private var grabber: some View {
        Capsule()
            .fill(palette.secondaryText.opacity(0.4))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(palette.hairline).frame(height: 1)
    }

    // MARK: - Helpers

    /// One slider section: eyebrow label + readout, then an `EditorialSlider`.
    private func sliderGroup(
        title: LocalizedStringKey,
        icon: LucideIcon,
        valueText: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        leadingIcon: LucideIcon,
        trailingIcon: LucideIcon,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ControlLabel(
                title: title, icon: icon, value: valueText, palette: palette
            )
            EditorialSlider(
                value: value,
                range: range,
                step: step,
                leadingIcon: leadingIcon,
                trailingIcon: trailingIcon,
                palette: palette,
                onChange: onChange
            )
        }
    }

    /// Mutate the live settings with a single in-out edit, the shared shape
    /// behind every control's binding here.
    private func updateSettings(_ mutate: (inout ReaderSettings) -> Void) {
        viewModel.updateSettings { current in
            var next = current
            mutate(&next)
            return next
        }
    }
}
