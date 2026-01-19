import XCTest
@testable import KochTrainer

final class StudentProgressTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.receiveLevel, 1)
        XCTAssertEqual(progress.sendLevel, 1)
        XCTAssertTrue(progress.characterStats.isEmpty)
        XCTAssertTrue(progress.sessionHistory.isEmpty)
    }

    func testInitializationWithCustomLevels() {
        let progress = StudentProgress(receiveLevel: 10, sendLevel: 5)

        XCTAssertEqual(progress.receiveLevel, 10)
        XCTAssertEqual(progress.sendLevel, 5)
    }

    func testInitializationClampsLevelAbove26() {
        let progress = StudentProgress(receiveLevel: 50, sendLevel: 30)

        XCTAssertEqual(progress.receiveLevel, 26)
        XCTAssertEqual(progress.sendLevel, 26)
    }

    func testInitializationClampsLevelBelowOne() {
        let progress = StudentProgress(receiveLevel: -5, sendLevel: 0)

        XCTAssertEqual(progress.receiveLevel, 1)
        XCTAssertEqual(progress.sendLevel, 1)
    }

    func testCurrentLevelReturnsMax() {
        let progress = StudentProgress(receiveLevel: 10, sendLevel: 5)

        XCTAssertEqual(progress.currentLevel, 10)
    }

    // MARK: - Level For Session Type Tests

    func testLevelForSessionType() {
        let progress = StudentProgress(receiveLevel: 8, sendLevel: 3)

        XCTAssertEqual(progress.level(for: .receive), 8)
        XCTAssertEqual(progress.level(for: .send), 3)
    }

    // MARK: - Unlocked Characters Tests

    func testUnlockedCharactersForReceive() {
        let progress = StudentProgress(receiveLevel: 5, sendLevel: 1)

        XCTAssertEqual(progress.unlockedCharacters(for: .receive), ["K", "M", "R", "S", "U"])
        XCTAssertEqual(progress.unlockedCharacters(for: .send), ["K"])
    }

    func testUnlockedCharactersAtLevel26() {
        let progress = StudentProgress(receiveLevel: 26, sendLevel: 26)

        XCTAssertEqual(progress.unlockedCharacters(for: .receive).count, 26)
        XCTAssertEqual(progress.unlockedCharacters(for: .send).count, 26)
    }

    // MARK: - Next Character Tests

    func testNextCharacterForSessionType() {
        let progress = StudentProgress(receiveLevel: 1, sendLevel: 5)

        XCTAssertEqual(progress.nextCharacter(for: .receive), "M")
        XCTAssertEqual(progress.nextCharacter(for: .send), "A")
    }

    func testNextCharacterAtLevel26() {
        let progress = StudentProgress(receiveLevel: 26, sendLevel: 26)

        XCTAssertNil(progress.nextCharacter(for: .receive))
        XCTAssertNil(progress.nextCharacter(for: .send))
    }

    // MARK: - Overall Accuracy Tests

    func testOverallAccuracyWithNoStats() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.overallAccuracy, 0)
    }

    func testOverallAccuracyWithStats() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)

        // (9 + 8) / (10 + 10) = 17/20 = 0.85
        XCTAssertEqual(progress.overallAccuracy, 0.85, accuracy: 0.001)
    }

    func testOverallAccuracyPerfect() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 10)

        XCTAssertEqual(progress.overallAccuracy, 1.0, accuracy: 0.001)
    }

    func testOverallAccuracyByDirection() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 10, sendCorrect: 5
        )

        XCTAssertEqual(progress.overallAccuracy(for: .receive), 0.9, accuracy: 0.001)
        XCTAssertEqual(progress.overallAccuracy(for: .send), 0.5, accuracy: 0.001)
    }

    // MARK: - Should Advance Tests

    func testShouldAdvanceAt90Percent() {
        XCTAssertTrue(StudentProgress.shouldAdvance(sessionAccuracy: 0.90, level: 1))
    }

    func testShouldAdvanceAbove90Percent() {
        XCTAssertTrue(StudentProgress.shouldAdvance(sessionAccuracy: 0.95, level: 1))
    }

    func testShouldNotAdvanceBelow90Percent() {
        XCTAssertFalse(StudentProgress.shouldAdvance(sessionAccuracy: 0.89, level: 1))
    }

    func testShouldNotAdvanceAtLevel26() {
        XCTAssertFalse(StudentProgress.shouldAdvance(sessionAccuracy: 1.0, level: 26))
    }

    // MARK: - Advance If Eligible Tests

    func testAdvanceIfEligibleReceiveSucceeds() {
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 0.92, sessionType: .receive)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(progress.receiveLevel, 6)
        XCTAssertEqual(progress.sendLevel, 3) // Unchanged
    }

    func testAdvanceIfEligibleSendSucceeds() {
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 0.92, sessionType: .send)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(progress.sendLevel, 4)
        XCTAssertEqual(progress.receiveLevel, 5) // Unchanged
    }

    func testAdvanceIfEligibleFailsBelowThreshold() {
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 0.85, sessionType: .receive)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(progress.receiveLevel, 5)
    }

    func testAdvanceIfEligibleFailsAtMaxLevel() {
        var progress = StudentProgress(receiveLevel: 26, sendLevel: 26)

        let didAdvanceReceive = progress.advanceIfEligible(sessionAccuracy: 1.0, sessionType: .receive)
        let didAdvanceSend = progress.advanceIfEligible(sessionAccuracy: 1.0, sessionType: .send)

        XCTAssertFalse(didAdvanceReceive)
        XCTAssertFalse(didAdvanceSend)
        XCTAssertEqual(progress.receiveLevel, 26)
        XCTAssertEqual(progress.sendLevel, 26)
    }

    // MARK: - Update Stats Tests

    func testUpdateStatsFromReceiveSession() {
        var progress = StudentProgress()
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [
                "K": CharacterStat(receiveAttempts: 10, receiveCorrect: 9),
                "M": CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
            ]
        )

        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(progress.characterStats["K"]?.receiveCorrect, 9)
        XCTAssertEqual(progress.characterStats["K"]?.sendAttempts, 0)
        XCTAssertEqual(progress.characterStats["M"]?.receiveAttempts, 10)
        XCTAssertEqual(progress.sessionHistory.count, 1)
    }

    func testUpdateStatsFromSendSession() {
        var progress = StudentProgress()
        let result = SessionResult(
            sessionType: .send,
            duration: 300,
            totalAttempts: 10,
            correctCount: 8,
            characterStats: [
                "K": CharacterStat(sendAttempts: 10, sendCorrect: 8)
            ]
        )

        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.sendAttempts, 10)
        XCTAssertEqual(progress.characterStats["K"]?.sendCorrect, 8)
        XCTAssertEqual(progress.characterStats["K"]?.receiveAttempts, 0)
    }

    func testUpdateStatsMergesBothDirections() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)

        let result = SessionResult(
            sessionType: .send,
            duration: 300,
            totalAttempts: 10,
            correctCount: 9,
            characterStats: [
                "K": CharacterStat(sendAttempts: 10, sendCorrect: 9)
            ]
        )

        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(progress.characterStats["K"]?.receiveCorrect, 8)
        XCTAssertEqual(progress.characterStats["K"]?.sendAttempts, 10)
        XCTAssertEqual(progress.characterStats["K"]?.sendCorrect, 9)
        XCTAssertEqual(progress.characterStats["K"]?.totalAttempts, 20)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)
        progress.characterStats["K"] = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 5, sendCorrect: 4
        )
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 8, receiveCorrect: 7)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.receiveLevel, 5)
        XCTAssertEqual(decoded.sendLevel, 3)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveCorrect, 9)
        XCTAssertEqual(decoded.characterStats["K"]?.sendAttempts, 5)
        XCTAssertEqual(decoded.characterStats["K"]?.sendCorrect, 4)
        XCTAssertEqual(decoded.characterStats["M"]?.receiveAttempts, 8)
    }

    func testMigrationFromOldFormat() throws {
        // Simulate old format with single currentLevel
        let oldJson = """
        {
            "currentLevel": 7,
            "characterStats": {},
            "sessionHistory": [],
            "startDate": 0
        }
        """
        let data = try XCTUnwrap(oldJson.data(using: .utf8))

        let decoded = try JSONDecoder().decode(StudentProgress.self, from: data)

        // Both levels should be migrated from old currentLevel
        XCTAssertEqual(decoded.receiveLevel, 7)
        XCTAssertEqual(decoded.sendLevel, 7)
    }
}

// MARK: - CharacterStat Tests

final class CharacterStatTests: XCTestCase {

    func testDefaultInitialization() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.receiveAttempts, 0)
        XCTAssertEqual(stat.receiveCorrect, 0)
        XCTAssertEqual(stat.sendAttempts, 0)
        XCTAssertEqual(stat.sendCorrect, 0)
        XCTAssertEqual(stat.totalAttempts, 0)
    }

    func testReceiveAccuracyWithNoAttempts() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.receiveAccuracy, 0)
    }

    func testSendAccuracyWithNoAttempts() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.sendAccuracy, 0)
    }

    func testReceiveAccuracyCalculation() {
        let stat = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)

        XCTAssertEqual(stat.receiveAccuracy, 0.8, accuracy: 0.001)
    }

    func testSendAccuracyCalculation() {
        let stat = CharacterStat(sendAttempts: 10, sendCorrect: 6)

        XCTAssertEqual(stat.sendAccuracy, 0.6, accuracy: 0.001)
    }

    func testCombinedAccuracy() {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 10, sendCorrect: 7
        )

        // (9 + 7) / (10 + 10) = 16/20 = 0.8
        XCTAssertEqual(stat.combinedAccuracy, 0.8, accuracy: 0.001)
    }

    func testAccuracyForSessionType() {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 10, sendCorrect: 5
        )

        XCTAssertEqual(stat.accuracy(for: .receive), 0.9, accuracy: 0.001)
        XCTAssertEqual(stat.accuracy(for: .send), 0.5, accuracy: 0.001)
    }

    func testTotalAttempts() {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 5, sendCorrect: 4
        )

        XCTAssertEqual(stat.totalAttempts, 15)
        XCTAssertEqual(stat.totalCorrect, 13)
    }

    func testMerge() {
        var stat1 = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)
        let stat2 = CharacterStat(sendAttempts: 5, sendCorrect: 4)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.receiveAttempts, 10)
        XCTAssertEqual(stat1.receiveCorrect, 8)
        XCTAssertEqual(stat1.sendAttempts, 5)
        XCTAssertEqual(stat1.sendCorrect, 4)
    }

    func testMergeAccumulatesSameDirection() {
        var stat1 = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)
        let stat2 = CharacterStat(receiveAttempts: 5, receiveCorrect: 5)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.receiveAttempts, 15)
        XCTAssertEqual(stat1.receiveCorrect, 13)
    }

    func testSessionTypeInitializer() {
        let receiveStat = CharacterStat(sessionType: .receive, attempts: 10, correct: 8)
        XCTAssertEqual(receiveStat.receiveAttempts, 10)
        XCTAssertEqual(receiveStat.receiveCorrect, 8)
        XCTAssertEqual(receiveStat.sendAttempts, 0)

        let sendStat = CharacterStat(sessionType: .send, attempts: 10, correct: 6)
        XCTAssertEqual(sendStat.sendAttempts, 10)
        XCTAssertEqual(sendStat.sendCorrect, 6)
        XCTAssertEqual(sendStat.receiveAttempts, 0)
    }
}
