import SwiftUI
import Charts

/// Local reading statistics: a current streak, total time read, and a
/// bar chart of the last fortnight's daily reading time. Themed with the
/// reader palette so it feels like part of the same surface. Strictly
/// local — no badges, no leaderboards, just the numbers.
struct StatsView: View {
    @Environment(StatsStore.self) private var statsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private static let chartDayCount = 14

    private var palette: ReaderPalette {
        settingsStore.settings.palette(systemDark: colorScheme == .dark)
    }

    private var dailyTotals: [(day: Date, seconds: TimeInterval)] {
        statsStore.stats.dailyTotals(
            lastDays: Self.chartDayCount, endingOn: .now
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    streakCard
                    chartSection
                    totalRow
                }
                .padding(24)
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
        .preferredColorScheme(palette.isDark ? .dark : .light)
    }

    // MARK: - Streak

    private var streakCard: some View {
        let streak = statsStore.stats.currentStreak
        return HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) day\(streak == 1 ? "" : "s")")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(palette.text)
                Text(streak == 0
                    ? "No active streak — open a book today"
                    : "Current reading streak")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats.streak")
        .accessibilityLabel("\(streak) day reading streak")
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last \(Self.chartDayCount) days")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(palette.text)

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
        HStack {
            Text("Total time read")
                .font(.system(size: 15))
                .foregroundStyle(palette.secondaryText)
            Spacer()
            Text(Self.formattedDuration(statsStore.stats.totalSeconds))
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(palette.text)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
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
