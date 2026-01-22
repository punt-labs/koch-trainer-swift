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
        var calendar = Calendar.current
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        // January 31, 2025 at 11:00 PM
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 31
        components.hour = 23
        components.minute = 0
        let jan31 = try XCTUnwrap(calendar.date(from: components))

        // February 1, 2025 at 8:00 AM
        components.month = 2
        components.day = 1
        components.hour = 8
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

    func testLeapYearFebruary28ToMarch1() throws {
        var calendar = Calendar.current
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        // February 28, 2024 (leap year) at 10:00 PM
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 28
        components.hour = 22
        let feb28 = try XCTUnwrap(calendar.date(from: components))

        // February 29, 2024 at 9:00 AM
        components.day = 29
        components.hour = 9
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

    // MARK: - DST Edge Case Tests

    func testDSTSpringForwardStreakContinues() throws {
        // US DST 2024: March 10, 2:00 AM -> 3:00 AM (lose 1 hour)
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // March 9, 2024 at 11:00 PM PST
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 9
        components.hour = 23
        components.minute = 0
        components.timeZone = pacificTZ
        let beforeDST = try XCTUnwrap(calendar.date(from: components))

        // March 10, 2024 at 10:00 AM PDT (after spring forward)
        components.day = 10
        components.hour = 10
        let afterDST = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: beforeDST,
            currentStreak: 5,
            longestStreak: 5,
            now: afterDST
        )

        // Should still be consecutive days despite the 23-hour day
        XCTAssertEqual(result.currentStreak, 6)
    }

    func testDSTFallBackStreakContinues() throws {
        // US DST 2024: November 3, 2:00 AM -> 1:00 AM (gain 1 hour)
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // November 2, 2024 at 10:00 PM PDT
        var components = DateComponents()
        components.year = 2024
        components.month = 11
        components.day = 2
        components.hour = 22
        components.minute = 0
        components.timeZone = pacificTZ
        let beforeDST = try XCTUnwrap(calendar.date(from: components))

        // November 3, 2024 at 8:00 AM PST (after fall back)
        components.day = 3
        components.hour = 8
        let afterDST = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: beforeDST,
            currentStreak: 10,
            longestStreak: 15,
            now: afterDST
        )

        // Should still be consecutive days despite the 25-hour day
        XCTAssertEqual(result.currentStreak, 11)
    }

    func testDSTSpringForwardSameDayPractice() throws {
        // Practice twice on the day of spring forward
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // March 10, 2024 at 1:00 AM PST (before spring forward)
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10
        components.hour = 1
        components.minute = 0
        components.timeZone = pacificTZ
        let earlyMorning = try XCTUnwrap(calendar.date(from: components))

        // March 10, 2024 at 4:00 PM PDT (after spring forward)
        components.hour = 16
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: earlyMorning,
            currentStreak: 3,
            longestStreak: 5,
            now: afternoon
        )

        // Same calendar day, streak should be maintained (not incremented)
        XCTAssertEqual(result.currentStreak, 3)
    }

    func testDSTFallBackSameDayPractice() throws {
        // Practice twice on the day of fall back (25-hour day)
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // November 3, 2024 at 1:00 AM PDT (first 1 AM, before fall back)
        var components = DateComponents()
        components.year = 2024
        components.month = 11
        components.day = 3
        components.hour = 1
        components.minute = 0
        components.timeZone = pacificTZ
        let firstOneAM = try XCTUnwrap(calendar.date(from: components))

        // November 3, 2024 at 6:00 PM PST (after fall back)
        components.hour = 18
        let evening = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.updateStreak(
            lastStreakDate: firstOneAM,
            currentStreak: 7,
            longestStreak: 10,
            now: evening
        )

        // Same calendar day, streak should be maintained
        XCTAssertEqual(result.currentStreak, 7)
    }

    // MARK: - Has Practiced Today DST Tests

    func testHasPracticedTodayAcrossDSTSpringForward() throws {
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // March 10, 2024 at 1:30 AM PST
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10
        components.hour = 1
        components.minute = 30
        components.timeZone = pacificTZ
        let morning = try XCTUnwrap(calendar.date(from: components))

        // March 10, 2024 at 3:30 PM PDT (after spring forward)
        components.hour = 15
        components.minute = 30
        let afternoon = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.hasPracticedToday(lastStreakDate: morning, now: afternoon)

        XCTAssertTrue(result)
    }

    // MARK: - Days Until Break DST Tests

    func testDaysUntilBreakAcrossDSTTransition() throws {
        guard let pacificTZ = TimeZone(identifier: "America/Los_Angeles") else {
            XCTFail("Could not create Pacific timezone")
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = pacificTZ

        // March 9, 2024 at 9:00 PM PST (day before spring forward)
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 9
        components.hour = 21
        components.timeZone = pacificTZ
        let dayBefore = try XCTUnwrap(calendar.date(from: components))

        // March 10, 2024 at 10:00 AM PDT (day of spring forward)
        components.day = 10
        components.hour = 10
        let dayOf = try XCTUnwrap(calendar.date(from: components))

        let result = StreakCalculator.daysUntilStreakBreaks(lastStreakDate: dayBefore, now: dayOf)

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

    func testStreakPreservedWhenCheckingFromDifferentTimezone() throws {
        // Practice in UTC, check streak in Pacific time
        // The calendar uses the device's current timezone, so dates should still work
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        // January 15, 2025 at 10:00 PM UTC
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 22
        components.timeZone = TimeZone(identifier: "UTC")
        let practiceDate = try XCTUnwrap(utcCalendar.date(from: components))

        // January 16, 2025 at 8:00 AM UTC (same as Jan 16 12:00 AM Pacific)
        components.day = 16
        components.hour = 8
        let checkDate = try XCTUnwrap(utcCalendar.date(from: components))

        // The StreakCalculator uses Calendar.current which uses the device timezone
        // Since both dates are absolute timestamps, the comparison should work
        let result = StreakCalculator.updateStreak(
            lastStreakDate: practiceDate,
            currentStreak: 3,
            longestStreak: 5,
            now: checkDate
        )

        // Should be consecutive days in any timezone
        XCTAssertEqual(result.currentStreak, 4)
    }
}
