@testable import KochTrainer
import XCTest

final class PausedSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let startTime = Date()
        let pausedAt = Date().addingTimeInterval(60)
        let session = PausedSession(
            sessionType: .receive,
            startTime: startTime,
            pausedAt: pausedAt,
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K", "M", "R"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )

        XCTAssertEqual(session.sessionType, .receive)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertEqual(session.pausedAt, pausedAt)
        XCTAssertEqual(session.correctCount, 10)
        XCTAssertEqual(session.totalAttempts, 15)
        XCTAssertEqual(session.introCharacters, ["K", "M", "R"])
        XCTAssertTrue(session.introCompleted)
        XCTAssertNil(session.customCharacters)
        XCTAssertEqual(session.currentLevel, 3)
    }

    func testCustomSessionInitialization() {
        let session = PausedSession(
            sessionType: .receiveCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 8,
            characterStats: [:],
            introCharacters: ["A", "B"],
            introCompleted: false,
            customCharacters: ["A", "B"],
            currentLevel: 5
        )

        XCTAssertEqual(session.sessionType, .receiveCustom)
        XCTAssertEqual(session.customCharacters, ["A", "B"])
        XCTAssertTrue(session.isCustomSession)
    }

    // MARK: - Computed Property Tests

    func testElapsedDuration() {
        let startTime = Date()
        let pausedAt = startTime.addingTimeInterval(120)
        let session = PausedSession(
            sessionType: .send,
            startTime: startTime,
            pausedAt: pausedAt,
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertEqual(session.elapsedDuration, 120, accuracy: 0.001)
    }

    func testIsExpiredWhenRecent() {
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date().addingTimeInterval(-3600),
            pausedAt: Date().addingTimeInterval(-60),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertFalse(session.isExpired)
    }

    func testIsExpiredWhenOlderThan24Hours() {
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date().addingTimeInterval(-48 * 3600),
            pausedAt: Date().addingTimeInterval(-25 * 3600),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertTrue(session.isExpired)
    }

    func testIsCustomSessionFalseWhenNoCustomCharacters() {
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertFalse(session.isCustomSession)
    }

    func testIsCustomSessionTrueWithCustomCharacters() {
        let session = PausedSession(
            sessionType: .receiveCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: ["X", "Y"],
            introCompleted: true,
            customCharacters: ["X", "Y"],
            currentLevel: 1
        )

        XCTAssertTrue(session.isCustomSession)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        let original = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date().addingTimeInterval(60),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [
                "K": CharacterStat(receiveAttempts: 5, receiveCorrect: 4),
                "M": CharacterStat(receiveAttempts: 10, receiveCorrect: 6)
            ],
            introCharacters: ["K", "M", "R"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PausedSession.self, from: encoded)

        XCTAssertEqual(decoded.sessionType, .receive)
        XCTAssertEqual(decoded.correctCount, 10)
        XCTAssertEqual(decoded.totalAttempts, 15)
        XCTAssertEqual(decoded.introCharacters, ["K", "M", "R"])
        XCTAssertTrue(decoded.introCompleted)
        XCTAssertNil(decoded.customCharacters)
        XCTAssertEqual(decoded.currentLevel, 3)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveAttempts, 5)
        XCTAssertEqual(decoded.characterStats["M"]?.receiveCorrect, 6)
    }

    func testEncodingDecodingWithCustomCharacters() throws {
        let original = PausedSession(
            sessionType: .sendCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 8,
            characterStats: [:],
            introCharacters: ["A", "B", "C"],
            introCompleted: false,
            customCharacters: ["A", "B", "C"],
            currentLevel: 5
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PausedSession.self, from: encoded)

        XCTAssertEqual(decoded.sessionType, .sendCustom)
        XCTAssertEqual(decoded.customCharacters, ["A", "B", "C"])
        XCTAssertFalse(decoded.introCompleted)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let id = UUID()
        let date = Date()
        let session1 = PausedSession(
            id: id,
            sessionType: .receive,
            startTime: date,
            pausedAt: date,
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        let session2 = PausedSession(
            id: id,
            sessionType: .receive,
            startTime: date,
            pausedAt: date,
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertEqual(session1, session2)
    }

    func testInequalityDifferentId() {
        let date = Date()
        let session1 = PausedSession(
            sessionType: .receive,
            startTime: date,
            pausedAt: date,
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        let session2 = PausedSession(
            sessionType: .receive,
            startTime: date,
            pausedAt: date,
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        XCTAssertNotEqual(session1, session2) // Different UUIDs
    }
}
