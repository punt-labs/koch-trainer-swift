@testable import KochTrainer
import XCTest

final class GracefulDecoderTests: XCTestCase {

    // MARK: - Standard Decode Tests

    func testDecodeValidProgressSucceeds() throws {
        let progress = StudentProgress(receiveLevel: 5, sendLevel: 3)
        let data = try JSONEncoder().encode(progress)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.receiveLevel, 5)
        XCTAssertEqual(decoded?.sendLevel, 3)
    }

    func testDecodeWithSchemaVersion() throws {
        let progress = StudentProgress(schemaVersion: 1, receiveLevel: 10, sendLevel: 8)
        let data = try JSONEncoder().encode(progress)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.schemaVersion, 1)
        XCTAssertEqual(decoded?.receiveLevel, 10)
        XCTAssertEqual(decoded?.sendLevel, 8)
    }

    // MARK: - Graceful Degradation Tests

    func testDecodeWithMissingSchemaVersionUsesDefault() throws {
        // Construct JSON without schemaVersion
        let json: [String: Any] = [
            "receiveLevel": 5,
            "sendLevel": 3,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.schemaVersion, StudentProgress.currentSchemaVersion)
        XCTAssertEqual(decoded?.receiveLevel, 5)
    }

    func testDecodeWithLegacyCurrentLevel() throws {
        // Old format with currentLevel instead of receive/send levels
        let json: [String: Any] = [
            "currentLevel": 7,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.receiveLevel, 7)
        XCTAssertEqual(decoded?.sendLevel, 7)
    }

    func testDecodeWithMissingLevelsUsesDefaults() throws {
        let json: [String: Any] = [
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.receiveLevel, 1)
        XCTAssertEqual(decoded?.sendLevel, 1)
    }

    // MARK: - Session Recovery Tests

    func testDecodeSkipsInvalidSessionsKeepsValid() throws {
        // Create JSON with one valid and one invalid session
        let validSession: [String: Any] = [
            "id": UUID().uuidString,
            "sessionType": "receive",
            "date": Date().timeIntervalSinceReferenceDate,
            "duration": 300.0,
            "totalAttempts": 10,
            "correctCount": 8,
            "characterStats": [String: Any]()
        ]

        let invalidSession: [String: Any] = [
            "id": "not-a-uuid", // Invalid UUID
            "sessionType": "unknown-type",
            "date": "invalid-date"
        ]

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [validSession, invalidSession],
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        // Should have recovered the valid session
        XCTAssertEqual(decoded?.sessionHistory.count, 1)
        XCTAssertEqual(decoded?.sessionHistory.first?.totalAttempts, 10)
    }

    func testDecodeWithEmptySessionHistorySucceeds() throws {
        let json: [String: Any] = [
            "receiveLevel": 2,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.sessionHistory.isEmpty ?? false)
    }

    // MARK: - Character Stats Recovery Tests

    func testDecodeRecoverValidCharacterStats() throws {
        let validStat: [String: Any] = [
            "receiveAttempts": 10,
            "receiveCorrect": 8,
            "sendAttempts": 5,
            "sendCorrect": 4,
            "lastPracticed": Date().timeIntervalSinceReferenceDate
        ]

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": ["K": validStat],
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(decoded?.characterStats["K"]?.receiveCorrect, 8)
    }

    func testDecodeSkipsInvalidCharacterStats() throws {
        let validStat: [String: Any] = [
            "receiveAttempts": 10,
            "receiveCorrect": 8,
            "sendAttempts": 5,
            "sendCorrect": 4,
            "lastPracticed": Date().timeIntervalSinceReferenceDate
        ]

        let invalidStat: [String: Any] = [
            "receiveAttempts": "not a number", // Invalid type
            "receiveCorrect": nil as Any? as Any
        ]

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": ["K": validStat, "M": invalidStat],
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertNotNil(decoded?.characterStats["K"])
        // M should be skipped due to invalid data
        XCTAssertNil(decoded?.characterStats["M"])
    }

    // MARK: - Schedule Recovery Tests

    func testDecodeRecoverSchedule() throws {
        let scheduleDict: [String: Any] = [
            "receiveInterval": 2.5,
            "sendInterval": 3.0,
            "currentStreak": 5,
            "longestStreak": 10,
            "levelReviewDates": [String: Any]()
        ]

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate,
            "schedule": scheduleDict
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.schedule.currentStreak, 5)
        XCTAssertEqual(decoded?.schedule.longestStreak, 10)
    }

    func testDecodeWithMissingScheduleUsesDefault() throws {
        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        // Default schedule values
        XCTAssertEqual(decoded?.schedule.receiveInterval, 1.0)
        XCTAssertEqual(decoded?.schedule.sendInterval, 1.0)
        XCTAssertEqual(decoded?.schedule.currentStreak, 0)
    }

    // MARK: - Date Parsing Tests

    func testDecodeWithNumericStartDate() throws {
        let timestamp = Date().timeIntervalSinceReferenceDate

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": timestamp
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        // Allow small tolerance for floating point
        XCTAssertEqual(decoded?.startDate.timeIntervalSinceReferenceDate ?? 0, timestamp, accuracy: 1.0)
    }

    func testDecodeWithISO8601StartDate() throws {
        let isoDate = "2024-06-15T10:30:00Z"
        let expectedDate = ISO8601DateFormatter().date(from: isoDate)

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": isoDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        if let expectedDate {
            XCTAssertEqual(
                decoded?.startDate.timeIntervalSince1970 ?? 0,
                expectedDate.timeIntervalSince1970,
                accuracy: 1.0
            )
        }
    }

    // MARK: - Word Stats Recovery Tests

    func testDecodeRecoverWordStats() throws {
        let wordStat: [String: Any] = [
            "receiveAttempts": 10,
            "receiveCorrect": 8,
            "sendAttempts": 5,
            "sendCorrect": 4,
            "lastPracticed": Date().timeIntervalSinceReferenceDate
        ]

        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate,
            "wordStats": ["hello": wordStat]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.wordStats["hello"]?.receiveAttempts, 10)
    }

    func testDecodeWithMissingWordStatsUsesEmpty() throws {
        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.wordStats.isEmpty ?? false)
    }

    // MARK: - Vocabulary Sets Recovery Tests

    func testDecodeWithMissingVocabularySetsUsesEmpty() throws {
        let json: [String: Any] = [
            "receiveLevel": 3,
            "sendLevel": 2,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = GracefulDecoder.decode(from: data)

        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.customVocabularySets.isEmpty ?? false)
    }

    // MARK: - Complete Failure Tests

    func testDecodeReturnsNilForInvalidJSON() {
        let invalidData = Data("not json".utf8)

        let decoded = GracefulDecoder.decode(from: invalidData)

        XCTAssertNil(decoded)
    }

    func testDecodeReturnsNilForEmptyData() {
        let emptyData = Data()

        let decoded = GracefulDecoder.decode(from: emptyData)

        XCTAssertNil(decoded)
    }

    func testDecodeReturnsNilForJSONArray() throws {
        let arrayData = try JSONSerialization.data(withJSONObject: [1, 2, 3])

        let decoded = GracefulDecoder.decode(from: arrayData)

        XCTAssertNil(decoded)
    }
}
