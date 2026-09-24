import SwiftUI

/// The flap's one action: a filled capsule with the price beside the verb
/// and, while a job runs, a fill that grows from the leading edge as
/// chapters land. Answers on touch-down (`PressScaleButtonStyle`).
struct TranslateCapsule: View {
    let title: String
    let price: String?
    /// 0…1 while something is running, nil otherwise.
    let progress: Double?
    let isEnabled: Bool
    let palette: BrandPalette
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(verbatim: title)
                    .font(Typography.control(15, weight: .semibold))
                    .lineLimit(1)
                if let price {
                    Text(verbatim: price)
                        .font(Typography.control(13.5, weight: .medium))
                        .monospacedDigit()
                        .opacity(0.85)
                }
            }
            .foregroundStyle(Color(hex: "#F7F5EE"))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                ZStack(alignment: .leading) {
                    palette.accent
                    if let progress {
                        GeometryReader { proxy in
                            palette.text.opacity(0.28)
                                .frame(width: proxy.size.width * min(max(progress, 0), 1))
                                .animation(.easeOut(duration: 0.4), value: progress)
                        }
                    }
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: palette.accent.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .opacity(isEnabled || progress != nil ? 1 : 0.55)
    }
}
