import SwiftUI

/// The app's bottom bar, drawn from the design tokens instead of UIKit's
/// appearance proxy only so the switch between destinations can animate.
/// It keeps the native tab bar's look — glyph, small label, tint on the
/// selection — and adds nothing but the icon's small bounce. Everything
/// settles critically damped — no overshoot on something a reader taps
/// tens of times a day.
struct AppTabBar<Tab: Hashable & CaseIterable>: View where Tab.AllCases: RandomAccessCollection {
    struct Item {
        let tab: Tab
        let title: LocalizedStringKey
        let icon: LucideIcon
        let identifier: String
    }

    let items: [Item]
    @Binding var selection: Tab
    let palette: BrandPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var indicator
    /// Per-tab tap counter: the symbol bounce keys off it so only the icon
    /// just chosen bounces, never the one being left.
    @State private var taps: [Tab: Int] = [:]

    /// Snappy and settled: Apple's "move" spring (damping 1.0), a hair
    /// quicker because the pill only travels a third of the screen.
    static var switchAnimation: Animation { .spring(response: 0.32, dampingFraction: 1) }

    var body: some View {
        // The system's floating tab bar: a glass capsule inset from the
        // edges, the selection a soft capsule that slides between items.
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                button(for: item)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs + 1)
        .background { barMaterial }
        .clipShape(Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
        .padding(.horizontal, Spacing.xl + Spacing.xs)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    @ViewBuilder
    private var barMaterial: some View {
        if reduceTransparency {
            palette.surface
        } else if #available(iOS 26, *) {
            Color.clear.glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            Rectangle().fill(.regularMaterial)
                .overlay(palette.surface.opacity(0.5))
        }
    }

    private func button(for item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            guard !isSelected else { return }
            taps[item.tab, default: 0] += 1
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : Self.switchAnimation) {
                selection = item.tab
            }
        } label: {
            VStack(spacing: Spacing.xxs) {
                BouncingTabIcon(
                    icon: item.icon,
                    tapCount: taps[item.tab, default: 0],
                    reduceMotion: reduceMotion
                )
                    .frame(width: 30, height: 26)
                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            // Ink, not the accent: the bar floats over covers and pages,
            // where the mid-tone accent and secondary text both wash out.
            // Selection reads from the pill and the full-strength ink.
            .foregroundStyle(isSelected ? palette.text : palette.text.opacity(0.62))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(palette.text.opacity(0.07))
                        .matchedGeometryEffect(id: "selection", in: indicator)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(TabPressStyle(reduceMotion: reduceMotion))
        .accessibilityIdentifier(item.identifier)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The selected tab's icon, with a small scale bounce standing in for the
/// SF Symbol `.bounce.down` effect Lucide's SVG images can't use.
private struct BouncingTabIcon: View {
    let icon: LucideIcon
    let tapCount: Int
    let reduceMotion: Bool

    @State private var isBouncing = false

    var body: some View {
        Icon(icon, size: 22)
            .scaleEffect(isBouncing && !reduceMotion ? 1.12 : 1)
            .onChange(of: tapCount) {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    isBouncing = true
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                        isBouncing = false
                    }
                }
            }
    }
}

/// Feedback on touch-down, not release: a quick dip the finger feels
/// answered by, gone before the switch animation is noticed.
private struct TabPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
