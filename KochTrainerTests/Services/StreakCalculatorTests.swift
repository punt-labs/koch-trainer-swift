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
}
