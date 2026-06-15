import XCTest
@testable import Quire

final class ReadingStatsTests: XCTestCase {

    private let calendar = Calendar.current

    private func day(_ daysAgo: Int, from reference: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    }

    // Fixed midday reference so day-boundary math is unambiguous.
    private var noonToday: Date {
        calendar.date(
            bySettingHour: 12, minute: 0, second: 0, of: Date()
        )!
    }

    // MARK: - addingSeconds

    func testAddingSecondsAccumulatesWithinSameDay() {
        let today = noonToday
        let stats = ReadingStats()
            .addingSeconds(60, on: today)
            .addingSeconds(90, on: today)

        XCTAssertEqual(stats.totalSeconds, 150, accuracy: 0.001)
    }

    func testAddingSecondsSeparatesAcrossDays() {
        let today = noonToday
        let yesterday = day(1, from: today)
        let stats = ReadingStats()
            .addingSeconds(60, on: today)
            .addingSeconds(120, on: yesterday)

        // Two distinct day buckets, total is the sum.
        XCTAssertEqual(stats.totalSeconds, 180, accuracy: 0.001)
        // Today bucket alone is one day in a one-day window.
        let todayWindow = stats.dailyTotals(lastDays: 1, endingOn: today)
        XCTAssertEqual(todayWindow.count, 1)
        XCTAssertEqual(todayWindow[0].seconds, 60, accuracy: 0.001)
    }

    func testAddingNonPositiveSecondsIsIgnored() {
        let stats = ReadingStats()
            .addingSeconds(0, on: noonToday)
            .addingSeconds(-50, on: noonToday)

        XCTAssertEqual(stats.totalSeconds, 0, accuracy: 0.001)
    }

    // MARK: - Streak

    func testEmptyStatsHaveZeroStreak() {
        XCTAssertEqual(ReadingStats().currentStreak(asOf: noonToday), 0)
    }

    func testConsecutiveDaysCountStreak() {
        let now = noonToday
        var stats = ReadingStats()
        for offset in 0..<4 {
            stats = stats.addingSeconds(300, on: day(offset, from: now))
        }
        XCTAssertEqual(stats.currentStreak(asOf: now), 4)
    }

    func testGapBreaksStreak() {
        let now = noonToday
        // Today and yesterday read, then a gap at day -2, then day -3.
        let stats = ReadingStats()
            .addingSeconds(300, on: day(0, from: now))
            .addingSeconds(300, on: day(1, from: now))
            .addingSeconds(300, on: day(3, from: now))

        XCTAssertEqual(stats.currentStreak(asOf: now), 2)
    }

    func testStreakAnchorsToYesterdayWhenTodayEmpty() {
        let now = noonToday
        // No reading today; yesterday and the day before were read.
        let stats = ReadingStats()
            .addingSeconds(300, on: day(1, from: now))
            .addingSeconds(300, on: day(2, from: now))

        XCTAssertEqual(stats.currentStreak(asOf: now), 2)
    }

    func testStreakBreaksWhenTodayAndYesterdayEmpty() {
        let now = noonToday
        // Last reading was two days ago — streak has lapsed.
        let stats = ReadingStats()
            .addingSeconds(300, on: day(2, from: now))
            .addingSeconds(300, on: day(3, from: now))

        XCTAssertEqual(stats.currentStreak(asOf: now), 0)
    }

    func testTodayOnlyIsStreakOfOne() {
        let now = noonToday
        let stats = ReadingStats().addingSeconds(300, on: now)
        XCTAssertEqual(stats.currentStreak(asOf: now), 1)
    }

    // MARK: - dailyTotals

    func testDailyTotalsReturnsRequestedWindowWithZeroDays() {
        let now = noonToday
        let stats = ReadingStats()
            .addingSeconds(120, on: day(0, from: now))
            .addingSeconds(240, on: day(2, from: now))

        let totals = stats.dailyTotals(lastDays: 5, endingOn: now)

        XCTAssertEqual(totals.count, 5)
        // Oldest first, newest last.
        XCTAssertTrue(totals[0].day < totals[4].day)
        // Newest day (today) has 120s; day -2 has 240s; others zero.
        XCTAssertEqual(totals[4].seconds, 120, accuracy: 0.001)
        XCTAssertEqual(totals[2].seconds, 240, accuracy: 0.001)
        XCTAssertEqual(totals[3].seconds, 0, accuracy: 0.001)
        XCTAssertEqual(totals[1].seconds, 0, accuracy: 0.001)
    }

    func testDailyTotalsOutsideWindowAreExcluded() {
        let now = noonToday
        let stats = ReadingStats()
            .addingSeconds(600, on: day(10, from: now))

        let totals = stats.dailyTotals(lastDays: 3, endingOn: now)

        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals.reduce(0) { $0 + $1.seconds }, 0, accuracy: 0.001)
    }

    func testDailyTotalsZeroWindowIsEmpty() {
        XCTAssertTrue(
            ReadingStats().dailyTotals(lastDays: 0, endingOn: noonToday).isEmpty
        )
    }
}
