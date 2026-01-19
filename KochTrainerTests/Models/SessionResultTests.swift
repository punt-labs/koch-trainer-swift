@testable import KochTrainer
import XCTest

final class SessionResultTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [:]
        )

        XCTAssertEqual(result.sessionType, .receive)
        XCTAssertEqual(result.duration, 300)
        XCTAssertEqual(result.totalAttempts, 50)
        XCTAssertEqual(result.correctCount, 45)
    }

    // MARK: - Accuracy Tests

    func testAccuracy() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 90,
            characterStats: [:]
        )

        XCTAssertEqual(result.accuracy, 0.9, accuracy: 0.001)
    }

    func testAccuracyWithZeroAttempts() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 0,
            correctCount: 0,
            characterStats: [:]
        )

        XCTAssertEqual(result.accuracy, 0)
    }

    func testAccuracyPercentage() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 87,
            characterStats: [:]
        )

        XCTAssertEqual(result.accuracyPercentage, 87)
    }

    func testAccuracyPercentageRounding() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 3,
            correctCount: 2,
            characterStats: [:]
        )

        // 2/3 = 0.666... → 67%
        XCTAssertEqual(result.accuracyPercentage, 67)
    }

    // MARK: - Formatted Duration Tests

    func testFormattedDuration5Minutes() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [:]
        )

        XCTAssertEqual(result.formattedDuration, "5:00")
    }

    func testFormattedDuration2Minutes30Seconds() {
        let result = SessionResult(
            sessionType: .receive,
            duration: 150,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [:]
        )

        XCTAssertEqual(result.formattedDuration, "2:30")
    }

    func testFormattedDuration45Seconds() {
        let result = SessionResult(
            sessionType: .send,
            duration: 45,
            totalAttempts: 10,
            correctCount: 9,
            characterStats: [:]
        )

        XCTAssertEqual(result.formattedDuration, "0:45")
    }

    func testFormattedDuration1Second() {
        let result = SessionResult(
            sessionType: .send,
            duration: 1,
            totalAttempts: 1,
            correctCount: 1,
            characterStats: [:]
        )

        XCTAssertEqual(result.formattedDuration, "0:01")
    }

    // MARK: - Session Type Tests

    func testSessionTypeReceive() {
        XCTAssertEqual(SessionType.receive.displayName, "Receive")
    }

    func testSessionTypeSend() {
        XCTAssertEqual(SessionType.send.displayName, "Send")
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        let original = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [
                "K": CharacterStat(receiveAttempts: 10, receiveCorrect: 9),
                "M": CharacterStat(receiveAttempts: 10, receiveCorrect: 8)
            ]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionResult.self, from: encoded)

        XCTAssertEqual(decoded.sessionType, .receive)
        XCTAssertEqual(decoded.duration, 300)
        XCTAssertEqual(decoded.totalAttempts, 50)
        XCTAssertEqual(decoded.correctCount, 45)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(decoded.characterStats["M"]?.receiveCorrect, 8)
    }

    // MARK: - Identifiable Tests

    func testUniqueIdentifiers() {
        let result1 = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [:]
        )

        let result2 = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 50,
            correctCount: 45,
            characterStats: [:]
        )

        XCTAssertNotEqual(result1.id, result2.id)
    }
}
