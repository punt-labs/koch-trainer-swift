@testable import KochTrainer
import XCTest

final class WordStatTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let stat = WordStat()

        XCTAssertEqual(stat.receiveAttempts, 0)
        XCTAssertEqual(stat.receiveCorrect, 0)
        XCTAssertEqual(stat.sendAttempts, 0)
        XCTAssertEqual(stat.sendCorrect, 0)
    }

    func testCustomInitialization() {
        let date = Date(timeIntervalSince1970: 1000)
        let stat = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 8,
            sendAttempts: 5,
            sendCorrect: 4,
            lastPracticed: date
        )

        XCTAssertEqual(stat.receiveAttempts, 10)
        XCTAssertEqual(stat.receiveCorrect, 8)
        XCTAssertEqual(stat.sendAttempts, 5)
        XCTAssertEqual(stat.sendCorrect, 4)
        XCTAssertEqual(stat.lastPracticed, date)
    }

    func testTotalAttempts() {
        let stat = WordStat(receiveAttempts: 10, sendAttempts: 5)

        XCTAssertEqual(stat.totalAttempts, 15)
    }

    func testTotalCorrect() {
        let stat = WordStat(receiveCorrect: 8, sendCorrect: 4)

        XCTAssertEqual(stat.totalCorrect, 12)
    }

    // MARK: - Accuracy Tests

    func testReceiveAccuracyWithAttempts() {
        let stat = WordStat(receiveAttempts: 10, receiveCorrect: 8)

        XCTAssertEqual(stat.receiveAccuracy, 0.8, accuracy: 0.001)
    }

    func testReceiveAccuracyWithNoAttempts() {
        let stat = WordStat(receiveAttempts: 0, receiveCorrect: 0)

        XCTAssertEqual(stat.receiveAccuracy, 0)
    }

    func testSendAccuracyWithAttempts() {
        let stat = WordStat(sendAttempts: 20, sendCorrect: 15)

        XCTAssertEqual(stat.sendAccuracy, 0.75, accuracy: 0.001)
    }

    func testSendAccuracyWithNoAttempts() {
        let stat = WordStat(sendAttempts: 0, sendCorrect: 0)

        XCTAssertEqual(stat.sendAccuracy, 0)
    }

    func testCombinedAccuracyWithAttempts() {
        let stat = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 8,
            sendAttempts: 10,
            sendCorrect: 6
        )

        // (8 + 6) / (10 + 10) = 14/20 = 0.7
        XCTAssertEqual(stat.combinedAccuracy, 0.7, accuracy: 0.001)
    }

    func testCombinedAccuracyWithNoAttempts() {
        let stat = WordStat()

        XCTAssertEqual(stat.combinedAccuracy, 0)
    }

    // MARK: - accuracy(for:) Tests

    func testAccuracyForReceiveSessionType() {
        let stat = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 9,
            sendAttempts: 10,
            sendCorrect: 5
        )

        XCTAssertEqual(stat.accuracy(for: .receive), 0.9, accuracy: 0.001)
    }

    func testAccuracyForSendSessionType() {
        let stat = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 9,
            sendAttempts: 10,
            sendCorrect: 5
        )

        XCTAssertEqual(stat.accuracy(for: .send), 0.5, accuracy: 0.001)
    }

    // MARK: - Merge Tests

    func testMergeAddsAttempts() {
        var stat1 = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 8,
            sendAttempts: 5,
            sendCorrect: 4
        )
        let stat2 = WordStat(
            receiveAttempts: 5,
            receiveCorrect: 4,
            sendAttempts: 3,
            sendCorrect: 2
        )

        stat1.merge(stat2)

        XCTAssertEqual(stat1.receiveAttempts, 15)
        XCTAssertEqual(stat1.receiveCorrect, 12)
        XCTAssertEqual(stat1.sendAttempts, 8)
        XCTAssertEqual(stat1.sendCorrect, 6)
    }

    func testMergeUpdatesLastPracticedWhenNewer() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)

        var stat1 = WordStat(lastPracticed: oldDate)
        let stat2 = WordStat(lastPracticed: newDate)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.lastPracticed, newDate)
    }

    func testMergeKeepsLastPracticedWhenOlder() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)

        var stat1 = WordStat(lastPracticed: newDate)
        let stat2 = WordStat(lastPracticed: oldDate)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.lastPracticed, newDate)
    }

    // MARK: - Edge Cases

    func testPerfectAccuracy() {
        let stat = WordStat(receiveAttempts: 100, receiveCorrect: 100)

        XCTAssertEqual(stat.receiveAccuracy, 1.0, accuracy: 0.001)
    }

    func testZeroAccuracy() {
        let stat = WordStat(receiveAttempts: 100, receiveCorrect: 0)

        XCTAssertEqual(stat.receiveAccuracy, 0.0, accuracy: 0.001)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = WordStat(
            receiveAttempts: 10,
            receiveCorrect: 8,
            sendAttempts: 5,
            sendCorrect: 4,
            lastPracticed: Date(timeIntervalSince1970: 1000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WordStat.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let date = Date(timeIntervalSince1970: 1000)
        let stat1 = WordStat(receiveAttempts: 10, receiveCorrect: 8, lastPracticed: date)
        let stat2 = WordStat(receiveAttempts: 10, receiveCorrect: 8, lastPracticed: date)

        XCTAssertEqual(stat1, stat2)
    }

    func testInequality() {
        let stat1 = WordStat(receiveAttempts: 10)
        let stat2 = WordStat(receiveAttempts: 11)

        XCTAssertNotEqual(stat1, stat2)
    }
}
