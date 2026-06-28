import SwiftUI
import Charts

/// Local reading statistics: a current streak, total time read, and a
/// bar chart of the last fortnight's daily reading time. Uses BrandPalette
/// to match the ambient library chrome — statistics are app-level context,
/// not a reading-surface concern.
struct StatsView: View {
    @Environment(StatsStore.self) private var statsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private static let chartDayCount = 14

    /// Brand palette — resolves to dark or light from the system appearance,
    /// consistent with the library from which this sheet is launched.
    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var dailyTotals: [(day: Date, seconds: TimeInterval)] {
        statsStore.stats.dailyTotals(
            lastDays: Self.chartDayCount, endingOn: .now
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    streakCard
                    chartSection
                    totalRow
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(palette.accent)
                }
            }
        }
    }

    // MARK: - Streak

    private var streakCard: some View {
        let streak = statsStore.stats.currentStreak
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            // Eyebrow labels the card as a named stat, not prose.
            HStack(spacing: Spacing.sm) {
                Text("Streak")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: Spacing.hairlineWidth)
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(palette.accent)

                // Display-weight number is the editorial anchor of the card.
                // Count as String so the key is "%@ day%@" (matches catalog).
                Text("\(String(streak)) day\(streak == 1 ? "" : "s")")
                    .font(Typography.display(36))
                    .foregroundStyle(palette.text)
            }

            Text(streak == 0
                ? "No active streak — open a book today"
                : "Current reading streak")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats.streak")
        .accessibilityLabel("\(streak) day reading streak")
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Eyebrow + hairline rule — same editorial device as the library's
            // section labels.
            HStack(spacing: Spacing.sm) {
                Text("This Week")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: Spacing.hairlineWidth)
            }

            Chart(dailyTotals, id: \.day) { entry in
                BarMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Minutes", entry.seconds / 60)
                )
                .foregroundStyle(palette.accent)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 200)
            .accessibilityIdentifier("stats.chart")
            .accessibilityLabel("Daily reading time, last \(Self.chartDayCount) days")
        }
    }

    // MARK: - Total

    private var totalRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Eyebrow labels this as a named aggregate, not an inline label.
            HStack(spacing: Spacing.sm) {
                Text("Total")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: Spacing.hairlineWidth)
            }

            HStack {
                Text(Self.formattedDuration(statsStore.stats.totalSeconds))
                    .font(Typography.display(30))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                Spacer()
                Text("total reading time")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Renders seconds as a compact `Xh Ym` / `Ym` string.
    static func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
