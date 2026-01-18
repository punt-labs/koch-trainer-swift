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
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 9)
        progress.characterStats["M"] = CharacterStat(totalAttempts: 10, correctCount: 8)

        // (9 + 8) / (10 + 10) = 17/20 = 0.85
        XCTAssertEqual(progress.overallAccuracy, 0.85, accuracy: 0.001)
    }

    func testOverallAccuracyPerfect() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 10)

        XCTAssertEqual(progress.overallAccuracy, 1.0, accuracy: 0.001)
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

    func testUpdateStatsFromSession() {
        var progress = StudentProgress()
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [
                "K": CharacterStat(totalAttempts: 10, correctCount: 9),
                "M": CharacterStat(totalAttempts: 10, correctCount: 9)
            ]
        )

        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.totalAttempts, 10)
        XCTAssertEqual(progress.characterStats["K"]?.correctCount, 9)
        XCTAssertEqual(progress.characterStats["M"]?.totalAttempts, 10)
        XCTAssertEqual(progress.sessionHistory.count, 1)
    }

    func testUpdateStatsAccumulates() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 8)

        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 10,
            correctCount: 9,
            characterStats: [
                "K": CharacterStat(totalAttempts: 10, correctCount: 9)
            ]
        )

        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.totalAttempts, 20)
        XCTAssertEqual(progress.characterStats["K"]?.correctCount, 17)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        var progress = StudentProgress(currentLevel: 5)
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 9)
        progress.characterStats["M"] = CharacterStat(totalAttempts: 8, correctCount: 7)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.currentLevel, 5)
        XCTAssertEqual(decoded.characterStats["K"]?.totalAttempts, 10)
        XCTAssertEqual(decoded.characterStats["K"]?.correctCount, 9)
        XCTAssertEqual(decoded.characterStats["M"]?.totalAttempts, 8)
    }
}

// MARK: - CharacterStat Tests

final class CharacterStatTests: XCTestCase {

    func testDefaultInitialization() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.totalAttempts, 0)
        XCTAssertEqual(stat.correctCount, 0)
    }

    func testAccuracyWithNoAttempts() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.accuracy, 0)
    }

    func testAccuracyCalculation() {
        let stat = CharacterStat(totalAttempts: 10, correctCount: 8)

        XCTAssertEqual(stat.accuracy, 0.8, accuracy: 0.001)
    }

    func testPerfectAccuracy() {
        let stat = CharacterStat(totalAttempts: 10, correctCount: 10)

        XCTAssertEqual(stat.accuracy, 1.0, accuracy: 0.001)
    }
}
