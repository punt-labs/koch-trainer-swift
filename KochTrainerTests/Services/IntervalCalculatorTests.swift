import XCTest
@testable import KochTrainer

final class IntervalCalculatorTests: XCTestCase {

    // MARK: - Calculate Next Interval Tests

    func testHighAccuracyDoublesInterval() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 2.0,
            accuracy: 0.95,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 4.0)
    }

    func testExactly90PercentDoublesInterval() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 1.0,
            accuracy: 0.90,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 2.0)
    }

    func testMediumAccuracyMaintainsInterval() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 4.0,
            accuracy: 0.75,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 4.0)
    }

    func testExactly70PercentMaintainsInterval() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 2.0,
            accuracy: 0.70,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 2.0)
    }

    func testLowAccuracyResetsToDaily() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 8.0,
            accuracy: 0.65,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 1.0)
    }

    func testVeryLowAccuracyResetsToDaily() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 4.0,
            accuracy: 0.30,
            daysSinceStart: 30
        )

        XCTAssertEqual(result, 1.0)
    }

    // MARK: - Habit Formation Cap Tests

    func testHabitPhaseCapsTwoDay() {
        // During first 14 days, max interval is 2 days
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 2.0,
            accuracy: 0.95,
            daysSinceStart: 7
        )

        // Would be 4.0, but capped at 2.0
        XCTAssertEqual(result, 2.0)
    }

    func testHabitPhaseAllowsDoubleToTwo() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 1.0,
            accuracy: 0.95,
            daysSinceStart: 5
        )

        XCTAssertEqual(result, 2.0)
    }

    func testAfterHabitPhaseAllowsLongerIntervals() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 8.0,
            accuracy: 0.95,
            daysSinceStart: 20
        )

        XCTAssertEqual(result, 16.0)
    }

    func testMaxIntervalCapped30Days() {
        let result = IntervalCalculator.calculateNextInterval(
            currentInterval: 20.0,
            accuracy: 0.95,
            daysSinceStart: 60
        )

        // Would be 40.0, but capped at 30.0
        XCTAssertEqual(result, 30.0)
    }

    // MARK: - Should Reset Interval Tests

    func testShouldResetWhenMissedDoubleInterval() {
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86400)

        let result = IntervalCalculator.shouldResetInterval(
            lastPractice: twoWeeksAgo,
            interval: 3.0  // More than 2 × 3 = 6 days ago
        )

        XCTAssertTrue(result)
    }

    func testShouldNotResetWithinDoubleInterval() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)

        let result = IntervalCalculator.shouldResetInterval(
            lastPractice: twoDaysAgo,
            interval: 2.0  // Within 2 × 2 = 4 days
        )

        XCTAssertFalse(result)
    }

    func testShouldNotResetExactlyAtDoubleInterval() {
        let now = Date()
        let fourDaysAgo = now.addingTimeInterval(-4 * 86400)

        let result = IntervalCalculator.shouldResetInterval(
            lastPractice: fourDaysAgo,
            interval: 2.0,  // Exactly at 2 × 2 = 4 days
            now: now
        )

        XCTAssertFalse(result)
    }

    func testShouldResetJustAfterDoubleInterval() {
        let now = Date()
        let overFourDaysAgo = now.addingTimeInterval(-4.1 * 86400)

        let result = IntervalCalculator.shouldResetInterval(
            lastPractice: overFourDaysAgo,
            interval: 2.0,  // Just past 2 × 2 = 4 days
            now: now
        )

        XCTAssertTrue(result)
    }

    // MARK: - Next Practice Date Tests

    func testNextPracticeDateCalculation() {
        let startDate = Date(timeIntervalSince1970: 0)
        let result = IntervalCalculator.nextPracticeDate(interval: 2.0, from: startDate)

        let expected = Date(timeIntervalSince1970: 2 * 86400)
        XCTAssertEqual(result.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
    }
}
