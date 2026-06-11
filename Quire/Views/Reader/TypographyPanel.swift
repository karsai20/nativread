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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                panelContent
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var panelContent: some View {
        Group {
            grabber

            themeRow

            autoThemeToggle

            divider

            comfortSection

            divider

            flowRow
            if settings.pageFlow == .paged {
                transitionRow
            }

            divider

            fontList

            divider

            sizeRow

            sliderRow(
                icon: "arrow.up.and.down.text.horizontal",
                label: "Line spacing",
                value: settings.lineHeight,
                range: ReaderSettings.lineHeightRange,
                step: 0.05
            ) { newValue in
                viewModel.updateSettings { current in
                    var next = current
                    next.lineHeight = newValue
                    return next
                }
            }

            sliderRow(
                icon: "rectangle.compress.vertical",
                label: "Margins",
                value: settings.horizontalMargin,
                range: ReaderSettings.marginRange,
                step: 2
            ) { newValue in
                viewModel.updateSettings { current in
                    var next = current
                    next.horizontalMargin = newValue
                    return next
                }
            }

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
                    .font(.system(size: 15))
            }
            .tint(palette.accent)
        }
    }

    // MARK: - Reading flow

    private var flowRow: some View {
        HStack(spacing: 10) {
            ForEach(PageFlow.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        next.pageFlow = candidate
                        return next
                    }
                } label: {
                    Label(candidate.label, systemImage: candidate.icon)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(candidate == settings.pageFlow
                            ? palette.accent.opacity(0.16)
                            : palette.text.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(candidate == settings.pageFlow
                            ? palette.accent
                            : palette.text.opacity(0.1))
                )
                .foregroundStyle(candidate == settings.pageFlow
                    ? palette.accent : palette.text)
                .accessibilityIdentifier("flow.\(candidate.rawValue)")
            }
        }
    }

    private var transitionRow: some View {
        HStack(spacing: 10) {
            Label("Page turn", systemImage: "arrow.right.square")
                .font(.system(size: 13))
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
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .background(
                    Capsule().fill(candidate == settings.pageTransition
                        ? palette.accent.opacity(0.16) : .clear)
                )
                .overlay(
                    Capsule().strokeBorder(
                        candidate == settings.pageTransition
                            ? palette.accent
                            : palette.text.opacity(0.12))
                )
                .foregroundStyle(candidate == settings.pageTransition
                    ? palette.accent : palette.secondaryText)
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
                .font(.system(size: 15))
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
            step: 0.05
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
            step: 0.05
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
        Rectangle().fill(palette.text.opacity(0.08)).frame(height: 1)
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
                                .frame(width: 44, height: 44)
                            Text("Aa")
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(candidate.text)
                        }
                        Text(candidate.label)
                            .font(.system(size: 11))
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
        HStack(spacing: 0) {
            Button {
                adjustFontSize(by: -1)
            } label: {
                Text("A")
                    .font(.system(size: 15, design: .serif))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .accessibilityIdentifier("fontsize.down")

            Rectangle()
                .fill(palette.text.opacity(0.1))
                .frame(width: 1, height: 22)

            Button {
                adjustFontSize(by: 1)
            } label: {
                Text("A")
                    .font(.system(size: 24, design: .serif))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .accessibilityIdentifier("fontsize.up")
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.text.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(palette.text.opacity(0.1))
        )
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
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
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
