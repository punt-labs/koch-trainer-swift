import XCTest
@testable import KochTrainer

final class StudentProgressTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.currentLevel, 1)
        XCTAssertTrue(progress.characterStats.isEmpty)
        XCTAssertTrue(progress.sessionHistory.isEmpty)
    }

    func testInitializationWithCustomLevel() {
        let progress = StudentProgress(currentLevel: 10)

        XCTAssertEqual(progress.currentLevel, 10)
    }

    func testInitializationClampsLevelAbove26() {
        let progress = StudentProgress(currentLevel: 50)

        XCTAssertEqual(progress.currentLevel, 26)
    }

    func testInitializationClampsLevelBelowOne() {
        let progress = StudentProgress(currentLevel: -5)

        XCTAssertEqual(progress.currentLevel, 1)
    }

    // MARK: - Unlocked Characters Tests

    func testUnlockedCharactersAtLevel1() {
        let progress = StudentProgress(currentLevel: 1)

        XCTAssertEqual(progress.unlockedCharacters, ["K"])
    }

    func testUnlockedCharactersAtLevel5() {
        let progress = StudentProgress(currentLevel: 5)

        XCTAssertEqual(progress.unlockedCharacters, ["K", "M", "R", "S", "U"])
    }

    func testUnlockedCharactersAtLevel26() {
        let progress = StudentProgress(currentLevel: 26)

        XCTAssertEqual(progress.unlockedCharacters.count, 26)
    }

    // MARK: - Next Character Tests

    func testNextCharacterAtLevel1() {
        let progress = StudentProgress(currentLevel: 1)

        XCTAssertEqual(progress.nextCharacter, "M")
    }

    func testNextCharacterAtLevel25() {
        let progress = StudentProgress(currentLevel: 25)

        XCTAssertEqual(progress.nextCharacter, "X")
    }

    func testNextCharacterAtLevel26() {
        let progress = StudentProgress(currentLevel: 26)

        XCTAssertNil(progress.nextCharacter)
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
        XCTAssertTrue(StudentProgress.shouldAdvance(sessionAccuracy: 0.90, currentLevel: 1))
    }

    func testShouldAdvanceAbove90Percent() {
        XCTAssertTrue(StudentProgress.shouldAdvance(sessionAccuracy: 0.95, currentLevel: 1))
    }

    func testShouldNotAdvanceBelow90Percent() {
        XCTAssertFalse(StudentProgress.shouldAdvance(sessionAccuracy: 0.89, currentLevel: 1))
    }

    func testShouldNotAdvanceAtLevel26() {
        XCTAssertFalse(StudentProgress.shouldAdvance(sessionAccuracy: 1.0, currentLevel: 26))
    }

    // MARK: - Advance If Eligible Tests

    func testAdvanceIfEligibleSucceeds() {
        var progress = StudentProgress(currentLevel: 5)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 0.92)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(progress.currentLevel, 6)
    }

    func testAdvanceIfEligibleFailsBelowThreshold() {
        var progress = StudentProgress(currentLevel: 5)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 0.85)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(progress.currentLevel, 5)
    }

    func testAdvanceIfEligibleFailsAtMaxLevel() {
        var progress = StudentProgress(currentLevel: 26)

        let didAdvance = progress.advanceIfEligible(sessionAccuracy: 1.0)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(progress.currentLevel, 26)
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
        var progress = StudentProgress(currentLevel: 5)
        progress.characterStats["K"] = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 5, sendCorrect: 4
        )
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 8, receiveCorrect: 7)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.currentLevel, 5)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(decoded.characterStats["K"]?.receiveCorrect, 9)
        XCTAssertEqual(decoded.characterStats["K"]?.sendAttempts, 5)
        XCTAssertEqual(decoded.characterStats["K"]?.sendCorrect, 4)
        XCTAssertEqual(decoded.characterStats["M"]?.receiveAttempts, 8)
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
