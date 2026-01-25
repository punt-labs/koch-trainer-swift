@testable import KochTrainer
import XCTest

@MainActor
final class SessionCounterTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_attemptsIsZero() {
        let counter = SessionCounter()
        XCTAssertEqual(counter.attempts, 0)
    }

    func testInitialState_correctIsZero() {
        let counter = SessionCounter()
        XCTAssertEqual(counter.correct, 0)
    }

    func testInitialState_accuracyIsZero() {
        let counter = SessionCounter()
        XCTAssertEqual(counter.accuracy, 0)
    }

    // MARK: - Record Attempt

    func testRecordAttempt_incrementsAttempts() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.attempts, 1)
    }

    func testRecordAttempt_correct_incrementsBothCounters() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: true)

        XCTAssertEqual(counter.attempts, 1)
        XCTAssertEqual(counter.correct, 1)
    }

    func testRecordAttempt_incorrect_onlyIncrementsAttempts() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.attempts, 1)
        XCTAssertEqual(counter.correct, 0)
    }

    func testRecordAttempt_multipleAttempts() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: false)
        counter.recordAttempt(wasCorrect: true)

        XCTAssertEqual(counter.attempts, 3)
        XCTAssertEqual(counter.correct, 2)
    }

    // MARK: - Invariant: correct ≤ attempts

    func testInvariant_correctNeverExceedsAttempts() {
        let counter = SessionCounter()

        // Run many random attempts
        for _ in 0 ..< 100 {
            counter.recordAttempt(wasCorrect: Bool.random())
            XCTAssertLessThanOrEqual(
                counter.correct,
                counter.attempts,
                "Invariant violated: correct (\(counter.correct)) > attempts (\(counter.attempts))"
            )
        }
    }

    func testInvariant_allCorrect_correctEqualsAttempts() {
        let counter = SessionCounter()

        for _ in 0 ..< 10 {
            counter.recordAttempt(wasCorrect: true)
        }

        XCTAssertEqual(counter.correct, counter.attempts)
    }

    func testInvariant_allIncorrect_correctIsZero() {
        let counter = SessionCounter()

        for _ in 0 ..< 10 {
            counter.recordAttempt(wasCorrect: false)
        }

        XCTAssertEqual(counter.correct, 0)
        XCTAssertEqual(counter.attempts, 10)
    }

    // MARK: - Accuracy

    func testAccuracy_noAttempts_returnsZero() {
        let counter = SessionCounter()
        XCTAssertEqual(counter.accuracy, 0)
    }

    func testAccuracy_allCorrect_returnsOne() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: true)

        XCTAssertEqual(counter.accuracy, 1.0)
    }

    func testAccuracy_allIncorrect_returnsZero() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: false)
        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.accuracy, 0)
    }

    func testAccuracy_mixedResults_calculatesCorrectly() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: false)
        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.accuracy, 0.5, accuracy: 0.001)
    }

    func testAccuracy_75Percent() {
        let counter = SessionCounter()

        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.accuracy, 0.75, accuracy: 0.001)
    }

    // MARK: - Reset

    func testReset_clearsAttempts() {
        let counter = SessionCounter()
        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: false)

        counter.reset()

        XCTAssertEqual(counter.attempts, 0)
    }

    func testReset_clearsCorrect() {
        let counter = SessionCounter()
        counter.recordAttempt(wasCorrect: true)
        counter.recordAttempt(wasCorrect: true)

        counter.reset()

        XCTAssertEqual(counter.correct, 0)
    }

    func testReset_resetsAccuracy() {
        let counter = SessionCounter()
        counter.recordAttempt(wasCorrect: true)

        counter.reset()

        XCTAssertEqual(counter.accuracy, 0)
    }

    func testReset_canRecordAfterReset() {
        let counter = SessionCounter()
        counter.recordAttempt(wasCorrect: true)
        counter.reset()

        counter.recordAttempt(wasCorrect: false)

        XCTAssertEqual(counter.attempts, 1)
        XCTAssertEqual(counter.correct, 0)
    }
}
