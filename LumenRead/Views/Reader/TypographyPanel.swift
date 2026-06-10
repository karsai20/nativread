import SwiftUI

/// The "Aa" appearance sheet: themes, typeface, size, spacing, margins.
struct TypographyPanel: View {
    @Bindable var viewModel: ReaderViewModel

    private var settings: ReaderSettings { viewModel.settings }
    private var theme: ReaderTheme { settings.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                panelContent
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var panelContent: some View {
        Group {
            grabber

            themeRow

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
            .tint(theme.accent)
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(theme.secondaryText.opacity(0.4))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(theme.text.opacity(0.08)).frame(height: 1)
    }

    // MARK: - Theme swatches

    private var themeRow: some View {
        HStack(spacing: 14) {
            ForEach(ReaderTheme.allCases) { candidate in
                Button {
                    viewModel.updateSettings { current in
                        var next = current
                        next.theme = candidate
                        return next
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(candidate.background)
                                .overlay(
                                    Circle().strokeBorder(
                                        candidate == theme
                                            ? candidate.accent
                                            : theme.text.opacity(0.15),
                                        lineWidth: candidate == theme ? 2 : 1
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
                                candidate == theme
                                    ? theme.accent : theme.secondaryText
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
                                .foregroundStyle(theme.accent)
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
                .fill(theme.text.opacity(0.1))
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
                .fill(theme.text.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.text.opacity(0.1))
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
                .foregroundStyle(theme.secondaryText)
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: range,
                step: step
            )
            .tint(theme.accent)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
