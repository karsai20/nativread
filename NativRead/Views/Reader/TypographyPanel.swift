import SwiftUI

/// The "Aa" appearance sheet: themes, typeface, size, spacing, margins.
///
/// Primary controls (theme, size, brightness) sit up top in the compact
/// detent; typeface and fine-tuning live behind "More". All sliders are the
/// hand-built `EditorialSlider`; swatches are page-like `ThemeTile`s.
struct TypographyPanel: View {
    @Bindable var viewModel: ReaderViewModel

    private var settings: ReaderSettings { viewModel.settings }
    private var palette: ReaderPalette { viewModel.palette }
    private var activeTheme: ReaderTheme {
        settings.effectiveTheme(systemDark: viewModel.systemDark)
    }

    @State private var brightness = UIScreen.main.brightness
    @State private var tab: AppearanceTab = Self.initialTab

    /// UI-test hook: `-appearanceTab text|layout` opens a specific tab for
    /// screenshots, mirroring the existing `-showTypographyPanel` argument.
    private static var initialTab: AppearanceTab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-appearanceTab"), i + 1 < args.count,
           let forced = AppearanceTab(rawValue: args[i + 1]) {
            return forced
        }
        return .theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            grabber
            SegmentedTabs(selection: $tab, palette: palette)
            ScrollView {
                tabContent
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(450), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .height(450)))
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.hidden)
    }

    /// The active tab's controls. Each tab is a calm, uncrowded column —
    /// no disclosure, no long scroll in the default detent.
    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .theme:  themeTab
        case .text:   textTab
        case .layout: layoutTab
        }
    }

    private var themeTab: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            themeRow
            autoThemeToggle
            divider
            warmthGroup
            brightnessGroup
        }
    }

    private var textTab: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sizeGroup
            divider
            fontList
            divider
            lineSpacingGroup
            justifiedToggle
        }
    }

    private var layoutTab: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            marginsGroup
            divider
            flowGroup
            if settings.pageFlow == .paged {
                transitionRow
            }
        }
    }

    // MARK: - Theme tiles

    private var themeRow: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(ReaderTheme.allCases) { candidate in
                ThemeTile(
                    theme: candidate,
                    isSelected: candidate == activeTheme,
                    palette: palette
                ) {
                    selectTheme(candidate)
                }
                .frame(maxWidth: .infinity)
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
                icon: "textformat.size",
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
            icon: "sun.max",
            valueText: "\(Int((brightness * 100).rounded()))%",
            value: brightness,
            range: 0.05...1,
            step: 0.05,
            leadingSymbol: "sun.min",
            trailingSymbol: "sun.max"
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
            icon: "thermometer.sun",
            valueText: "\(Int((settings.warmth * 100).rounded()))%",
            value: settings.warmth,
            range: ReaderSettings.warmthRange,
            step: 0.05,
            leadingSymbol: "moon",
            trailingSymbol: "thermometer.sun"
        ) { newValue in
            updateSettings { $0.warmth = newValue }
        }
        .accessibilityIdentifier("comfort.warmth")
    }

    private var lineSpacingGroup: some View {
        sliderGroup(
            title: "Line spacing",
            icon: "arrow.up.and.down.text.horizontal",
            valueText: String(format: "%.2f", settings.lineHeight),
            value: settings.lineHeight,
            range: ReaderSettings.lineHeightRange,
            step: 0.05,
            leadingSymbol: "text.alignleft",
            trailingSymbol: "text.justify"
        ) { newValue in
            updateSettings { $0.lineHeight = newValue }
        }
    }

    private var marginsGroup: some View {
        sliderGroup(
            title: "Margins",
            icon: "rectangle.compress.vertical",
            valueText: "\(Int(settings.horizontalMargin.rounded())) pt",
            value: settings.horizontalMargin,
            range: ReaderSettings.marginRange,
            step: 2,
            leadingSymbol: "rectangle.compress.vertical",
            trailingSymbol: "rectangle.expand.vertical"
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
            Label("Justified text", systemImage: "text.justify")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
    }

    private var autoThemeToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.themeMode == .system },
            set: { isOn in
                updateSettings { $0.themeMode = isOn ? .system : .manual }
            }
        )) {
            Label("Match system appearance",
                  systemImage: "circle.lefthalf.filled")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .accessibilityIdentifier("theme.auto")
    }

    // MARK: - Reading flow

    private var flowGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ControlLabel(title: "Page flow", icon: "book.pages", palette: palette)
            flowRow
        }
    }

    private var flowRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PageFlow.allCases) { candidate in
                Button {
                    updateSettings { $0.pageFlow = candidate }
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
            Label("Page turn", systemImage: "arrow.right.square")
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Spacer()
            ForEach(PageTransition.allCases) { candidate in
                Button {
                    updateSettings { $0.pageTransition = candidate }
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
                .accessibilityIdentifier("transition.\(candidate.rawValue)")
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
                            .font(candidate.previewFont)
                        Spacer()
                        if candidate == settings.font {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
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
        icon: String,
        valueText: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        leadingSymbol: String,
        trailingSymbol: String,
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
                leadingSymbol: leadingSymbol,
                trailingSymbol: trailingSymbol,
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
