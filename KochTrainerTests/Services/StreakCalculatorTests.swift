@testable import KochTrainer
import XCTest

final class StreakCalculatorTests: XCTestCase {

    // MARK: - First Session Tests

    func testFirstSessionStartsStreakAtOne() {
        let result = StreakCalculator.updateStreak(
            lastStreakDate: nil,
            currentStreak: 0,
            longestStreak: 0
        )

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 1)
    }

    func testFirstSessionPreservesExistingLongestStreak() {
        let result = StreakCalculator.updateStreak(
            lastStreakDate: nil,
            currentStreak: 0,
            longestStreak: 5 // From previous data migration
        )

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 5)
    }

    // MARK: - Consecutive Day Tests

    func testConsecutiveDayExtendsStreak() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: yesterday,
            currentStreak: 3,
            longestStreak: 5,
            now: now
        )

        XCTAssertEqual(result.currentStreak, 4)
        XCTAssertEqual(result.longestStreak, 5)
    }

    func testConsecutiveDayUpdatesLongestIfExceeded() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: yesterday,
            currentStreak: 5,
            longestStreak: 5,
            now: now
        )

        XCTAssertEqual(result.currentStreak, 6)
        XCTAssertEqual(result.longestStreak, 6)
    }

    // MARK: - Same Day Tests

    func testSameDayPracticeMaintainsStreak() throws {
        // Create a date that's definitely on the same day (use noon to avoid boundary issues)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        let noon = try XCTUnwrap(calendar.date(from: components))

        components.hour = 8
        let morning = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: morning,
            currentStreak: 5,
            longestStreak: 10,
            now: noon
        )

        XCTAssertEqual(result.currentStreak, 5)
        XCTAssertEqual(result.longestStreak, 10)
    }

    // MARK: - Streak Break Tests

    func testSkippedDayResetsStreak() throws {
        let now = Date()
        let twoDaysAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -2, to: now))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: twoDaysAgo,
            currentStreak: 7,
            longestStreak: 10,
            now: now
        )

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 10) // Longest preserved
    }

    func testWeekOffResetsStreak() throws {
        let now = Date()
        let weekAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -7, to: now))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: weekAgo,
            currentStreak: 15,
            longestStreak: 15,
            now: now
        )

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 15)
    }

    // MARK: - Has Practiced Today Tests

    func testHasPracticedTodayTrue() throws {
        // Create dates that are definitely on the same day
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 0
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        components.hour = 9
        let morning = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.hasPracticedToday(lastStreakDate: morning, now: afternoon)

        XCTAssertTrue(result)
    }

    func testHasPracticedTodayFalseWhenYesterday() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))

        let result = StreakCalculator.hasPracticedToday(lastStreakDate: yesterday, now: now)

        XCTAssertFalse(result)
    }

    func testHasPracticedTodayFalseWhenNil() {
        let result = StreakCalculator.hasPracticedToday(lastStreakDate: nil)

        XCTAssertFalse(result)
    }

    // MARK: - Days Until Streak Breaks Tests

    func testDaysUntilBreakWhenPracticedToday() throws {
        // Create dates that are definitely on the same day
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 16
        components.minute = 0
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        components.hour = 10
        let morning = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: morning, now: afternoon)

        XCTAssertEqual(result, 1) // Safe through tomorrow
    }

    func testDaysUntilBreakWhenPracticedYesterday() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))

        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: yesterday, now: now)

        XCTAssertEqual(result, 0) // Must practice today
    }

    func testDaysUntilBreakWhenStreakBroken() throws {
        let now = Date()
        let twoDaysAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -2, to: now))

        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: twoDaysAgo, now: now)

        XCTAssertEqual(result, -1) // Already broken
    }

    func testDaysUntilBreakWhenNoHistory() {
        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: nil)

        XCTAssertEqual(result, 0) // No streak to break, but indicates action needed
    }

    // MARK: - Edge Cases

    func testMidnightBoundary() throws {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 1 // Just after midnight

        let justAfterMidnight = try XCTUnwrap(calendar.date(from: components))

        guard let currentDay = components.day else {
            XCTFail("Could not get day component")
            return
        }
        components.day = currentDay - 1
        components.hour = 23
        components.minute = 59
        let justBeforeMidnight = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: justBeforeMidnight,
            currentStreak: 3,
            longestStreak: 5,
            now: justAfterMidnight
        )

        // Should count as consecutive days
        XCTAssertEqual(result.currentStreak, 4)
    }

    // MARK: - Calendar Boundary Tests

    func testMonthBoundaryJanuaryToFebruary() throws {
        let calendar = Calendar.current

        // January 31, 2025 at 2:00 PM local time
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 31
        components.hour = 14
        components.minute = 0
        let jan31 = try XCTUnwrap(calendar.date(from: components))

        // February 1, 2025 at 10:00 AM local time
        components.month = 2
        components.day = 1
        components.hour = 10
        let feb1 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: jan31,
            currentStreak: 5,
            longestStreak: 5,
            now: feb1
        )

        XCTAssertEqual(result.currentStreak, 6)
    }

    func testYearBoundaryDecemberToJanuary() throws {
        // Use device's calendar to ensure dates are in local timezone
        let calendar = Calendar.current

        // December 31, 2025 at 2:00 PM local time
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 14
        components.minute = 0
        let dec31 = try XCTUnwrap(calendar.date(from: components))

        // January 1, 2026 at 10:00 AM local time
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 10
        components.minute = 0
        let jan1 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: dec31,
            currentStreak: 10,
            longestStreak: 10,
            now: jan1
        )

        XCTAssertEqual(result.currentStreak, 11)
        XCTAssertEqual(result.longestStreak, 11)
    }

    func testLeapYearFebruary28ToFebruary29() throws {
        let calendar = Calendar.current

        // February 28, 2024 (leap year) at 2:00 PM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 28
        components.hour = 14
        let feb28 = try XCTUnwrap(calendar.date(from: components))

        // February 29, 2024 at 10:00 AM local time
        components.day = 29
        components.hour = 10
        let feb29 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: feb28,
            currentStreak: 3,
            longestStreak: 5,
            now: feb29
        )

        XCTAssertEqual(result.currentStreak, 4)
    }

    func testLeapYearFebruary29ToMarch1() throws {
        let calendar = Calendar.current

        // February 29, 2024 (leap year) at 2:00 PM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 29
        components.hour = 14
        let feb29 = try XCTUnwrap(calendar.date(from: components))

        // March 1, 2024 at 10:00 AM local time
        components.month = 3
        components.day = 1
        components.hour = 10
        let mar1 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: feb29,
            currentStreak: 4,
            longestStreak: 5,
            now: mar1
        )

        XCTAssertEqual(result.currentStreak, 5)
        XCTAssertEqual(result.longestStreak, 5)
    }

    func testNonLeapYearFebruary28ToMarch1() throws {
        let calendar = Calendar.current

        // February 28, 2025 (non-leap year) at 3:00 PM local time
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 28
        components.hour = 15
        let feb28 = try XCTUnwrap(calendar.date(from: components))

        // March 1, 2025 at 11:00 AM local time
        components.month = 3
        components.day = 1
        components.hour = 11
        let mar1 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: feb28,
            currentStreak: 7,
            longestStreak: 10,
            now: mar1
        )

        XCTAssertEqual(result.currentStreak, 8)
    }

    // MARK: - Consecutive Day Tests
    //
    // These tests verify that consecutive calendar days properly extend streaks.
    // StreakCalculator uses Calendar.current internally, which handles DST automatically.
    // We use mid-day times to avoid midnight edge cases.

    func testConsecutiveDaysExtendStreak() throws {
        let calendar = Calendar.current

        // Day 1 at 2:00 PM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 9
        components.hour = 14
        components.minute = 0
        let day1 = try XCTUnwrap(calendar.date(from: components))

        // Day 2 at 10:00 AM local time
        components.day = 10
        components.hour = 10
        let day2 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: day1,
            currentStreak: 5,
            longestStreak: 5,
            now: day2
        )

        XCTAssertEqual(result.currentStreak, 6)
    }

    func testConsecutiveDaysWithLargeGapExtendStreak() throws {
        let calendar = Calendar.current

        // Day 1 at 10:00 PM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 11
        components.day = 2
        components.hour = 22
        components.minute = 0
        let day1 = try XCTUnwrap(calendar.date(from: components))

        // Day 2 at 8:00 AM local time (consecutive day, ~10 hour gap)
        components.day = 3
        components.hour = 8
        let day2 = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: day1,
            currentStreak: 10,
            longestStreak: 15,
            now: day2
        )

        XCTAssertEqual(result.currentStreak, 11)
    }

    func testSameDayPracticeMorningToAfternoon() throws {
        let calendar = Calendar.current

        // Same day at 9:00 AM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10
        components.hour = 9
        components.minute = 0
        let morning = try XCTUnwrap(calendar.date(from: components))

        // Same day at 4:00 PM local time
        components.hour = 16
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: morning,
            currentStreak: 3,
            longestStreak: 5,
            now: afternoon
        )

        // Same calendar day, streak should be maintained (not incremented)
        XCTAssertEqual(result.currentStreak, 3)
    }

    func testSameDayPracticeEarlyToLate() throws {
        let calendar = Calendar.current

        // Same day at 6:00 AM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 11
        components.day = 3
        components.hour = 6
        components.minute = 0
        let early = try XCTUnwrap(calendar.date(from: components))

        // Same day at 6:00 PM local time
        components.hour = 18
        let late = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: early,
            currentStreak: 7,
            longestStreak: 10,
            now: late
        )

        // Same calendar day, streak should be maintained
        XCTAssertEqual(result.currentStreak, 7)
    }

    // MARK: - Has Practiced Today Tests

    func testHasPracticedTodaySameDay() throws {
        let calendar = Calendar.current

        // Same day at 9:30 AM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10
        components.hour = 9
        components.minute = 30
        let morning = try XCTUnwrap(calendar.date(from: components))

        // Same day at 3:30 PM local time
        components.hour = 15
        components.minute = 30
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.hasPracticedToday(lastStreakDate: morning, now: afternoon)

        XCTAssertTrue(result)
    }

    // MARK: - Days Until Break Tests

    func testDaysUntilBreakNextDay() throws {
        let calendar = Calendar.current

        // Yesterday at 2:00 PM local time
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 9
        components.hour = 14
        let yesterday = try XCTUnwrap(calendar.date(from: components))

        // Today at 10:00 AM local time
        components.day = 10
        components.hour = 10
        let today = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: yesterday, now: today)

        // Should be 0 - must practice today to continue streak
        XCTAssertEqual(result, 0)
    }

    // MARK: - Timezone Change Simulation Tests

    func testStreakWithLocalMidnightBoundary() throws {
        // Test dates very close to local midnight but on different calendar days
        let calendar = Calendar.current

        // Get today's date at 11:59 PM local time
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        let justBeforeMidnight = try XCTUnwrap(calendar.date(from: components))

        // Tomorrow at 12:01 AM local time
        guard let day = components.day else {
            XCTFail("Could not get day component")
            return
        }
        components.day = day + 1
        components.hour = 0
        components.minute = 1
        let justAfterMidnight = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: justBeforeMidnight,
            currentStreak: 5,
            longestStreak: 5,
            now: justAfterMidnight
        )

        // 2 minutes apart but different calendar days = consecutive
        XCTAssertEqual(result.currentStreak, 6)
    }

    func testConsecutiveDaysEveningToMorning() throws {
        let calendar = Calendar.current

        // Day 1 at 10:00 PM local time
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 22
        let day1Evening = try XCTUnwrap(calendar.date(from: components))

        // Day 2 at 8:00 AM local time
        components.day = 16
        components.hour = 8
        let day2Morning = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: day1Evening,
            currentStreak: 3,
            longestStreak: 5,
            now: day2Morning
        )

        // Consecutive calendar days should extend streak
        XCTAssertEqual(result.currentStreak, 4)
    }
}
