@testable import KochTrainer
import XCTest

// MARK: - StudentProgressTests

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

    // MARK: - Ear Training Level Tests

    func testDefaultEarTrainingLevel() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.earTrainingLevel, 1)
    }

    func testEarTrainingLevelInitialization() {
        let progress = StudentProgress(earTrainingLevel: 3)

        XCTAssertEqual(progress.earTrainingLevel, 3)
    }

    func testEarTrainingLevelClampsAbove5() {
        let progress = StudentProgress(earTrainingLevel: 10)

        XCTAssertEqual(progress.earTrainingLevel, 5)
    }

    func testEarTrainingLevelClampsBelowOne() {
        let progress = StudentProgress(earTrainingLevel: -2)

        XCTAssertEqual(progress.earTrainingLevel, 1)
    }

    func testEncodingDecodingEarTrainingLevel() throws {
        let progress = StudentProgress(earTrainingLevel: 4)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.earTrainingLevel, 4)
    }

    func testMigrationDefaultsEarTrainingLevelToOne() throws {
        // Simulate old format without earTrainingLevel
        let oldJson = """
        {
            "receiveLevel": 5,
            "sendLevel": 3,
            "characterStats": {},
            "sessionHistory": [],
            "startDate": 0
        }
        """
        let data = try XCTUnwrap(oldJson.data(using: .utf8))

        let decoded = try JSONDecoder().decode(StudentProgress.self, from: data)

        XCTAssertEqual(decoded.earTrainingLevel, 1)
    }

    // MARK: - Word Stats Tests

    func testDefaultWordStatsIsEmpty() {
        let progress = StudentProgress()

        XCTAssertTrue(progress.wordStats.isEmpty)
    }

    func testWordStatsInitialization() {
        let stats = ["CQ": WordStat(receiveAttempts: 10, receiveCorrect: 8)]
        let progress = StudentProgress(wordStats: stats)

        XCTAssertEqual(progress.wordStats["CQ"]?.receiveAttempts, 10)
        XCTAssertEqual(progress.wordStats["CQ"]?.receiveCorrect, 8)
    }

    func testEncodingDecodingWordStats() throws {
        var progress = StudentProgress()
        progress.wordStats["CQ"] = WordStat(receiveAttempts: 5, receiveCorrect: 4)
        progress.wordStats["DE"] = WordStat(sendAttempts: 3, sendCorrect: 2)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.wordStats["CQ"]?.receiveAttempts, 5)
        XCTAssertEqual(decoded.wordStats["DE"]?.sendAttempts, 3)
    }

    func testMigrationDefaultsWordStatsToEmpty() throws {
        // Simulate old format without wordStats
        let oldJson = """
        {
            "receiveLevel": 5,
            "sendLevel": 3,
            "characterStats": {},
            "sessionHistory": [],
            "startDate": 0
        }
        """
        let data = try XCTUnwrap(oldJson.data(using: .utf8))

        let decoded = try JSONDecoder().decode(StudentProgress.self, from: data)

        XCTAssertTrue(decoded.wordStats.isEmpty)
    }

    // MARK: - Custom Vocabulary Sets Tests

    func testDefaultCustomVocabularySetsIsEmpty() {
        let progress = StudentProgress()

        XCTAssertTrue(progress.customVocabularySets.isEmpty)
    }

    func testCustomVocabularySetsInitialization() {
        let sets = [VocabularySet(name: "My Set", words: ["CQ", "DE"], isBuiltIn: false)]
        let progress = StudentProgress(customVocabularySets: sets)

        XCTAssertEqual(progress.customVocabularySets.count, 1)
        XCTAssertEqual(progress.customVocabularySets.first?.name, "My Set")
    }

    func testEncodingDecodingCustomVocabularySets() throws {
        var progress = StudentProgress()
        progress.customVocabularySets = [VocabularySet(name: "Test", words: ["A", "B"])]

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.customVocabularySets.count, 1)
        XCTAssertEqual(decoded.customVocabularySets.first?.name, "Test")
    }

    // MARK: - Session History Tests

    func testUpdateStatsAppendsToSessionHistory() {
        var progress = StudentProgress()
        XCTAssertEqual(progress.sessionHistory.count, 0)

        let result1 = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 10,
            correctCount: 9,
            characterStats: [:]
        )
        progress.updateStats(from: result1)
        XCTAssertEqual(progress.sessionHistory.count, 1)

        let result2 = SessionResult(
            sessionType: .send,
            duration: 200,
            totalAttempts: 8,
            correctCount: 7,
            characterStats: [:]
        )
        progress.updateStats(from: result2)
        XCTAssertEqual(progress.sessionHistory.count, 2)
    }

    func testUpdateStatsMergesCharacterStats() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)

        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 5,
            correctCount: 4,
            characterStats: ["K": CharacterStat(receiveAttempts: 5, receiveCorrect: 5)]
        )
        progress.updateStats(from: result)

        XCTAssertEqual(progress.characterStats["K"]?.receiveAttempts, 15)
        XCTAssertEqual(progress.characterStats["K"]?.receiveCorrect, 13)
    }

    // MARK: - Calculate Initial Schedule Tests

    func testCalculateInitialScheduleReturnsDefaultForEmptyHistory() {
        let schedule = StudentProgress.calculateInitialSchedule(from: [], startDate: Date())

        XCTAssertEqual(schedule.receiveInterval, 1.0)
        XCTAssertEqual(schedule.sendInterval, 1.0)
        XCTAssertEqual(schedule.currentStreak, 0)
        XCTAssertEqual(schedule.longestStreak, 0)
    }

    func testCalculateInitialScheduleCalculatesStreakFromHistory() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))

        let sessions = [
            SessionResult(
                sessionType: .receive,
                duration: 300,
                totalAttempts: 10,
                correctCount: 9,
                characterStats: [:],
                date: yesterday
            ),
            SessionResult(
                sessionType: .receive,
                duration: 300,
                totalAttempts: 10,
                correctCount: 9,
                characterStats: [:],
                date: today
            )
        ]

        let schedule = StudentProgress.calculateInitialSchedule(from: sessions, startDate: yesterday)

        // Two consecutive days should give streak of 2
        XCTAssertEqual(schedule.currentStreak, 2)
        XCTAssertEqual(schedule.longestStreak, 2)
    }

    // MARK: - Schema Version Tests

    func testSchemaVersionDefault() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.schemaVersion, StudentProgress.currentSchemaVersion)
    }

    func testSchemaVersionEncodedAndDecoded() throws {
        let progress = StudentProgress(schemaVersion: 1)

        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(StudentProgress.self, from: encoded)

        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    // MARK: - Overall Accuracy Direction-Specific Tests

    func testOverallAccuracyForReceiveWithNoAttempts() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.overallAccuracy(for: .receive), 0)
    }

    func testOverallAccuracyForSendWithNoAttempts() {
        let progress = StudentProgress()

        XCTAssertEqual(progress.overallAccuracy(for: .send), 0)
    }

    func testOverallAccuracyCombinesMultipleCharacters() {
        var progress = StudentProgress()
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 10)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 5)

        // 15/20 = 0.75
        XCTAssertEqual(progress.overallAccuracy(for: .receive), 0.75, accuracy: 0.001)
    }
}

// MARK: - CharacterStatTests

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

    func testKochAccuracy() {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 9,
            sendAttempts: 10, sendCorrect: 7,
            earTrainingAttempts: 5, earTrainingCorrect: 5
        )

        // Koch accuracy excludes ear training: (9 + 7) / (10 + 10) = 16/20 = 0.8
        XCTAssertEqual(stat.kochAccuracy, 0.8, accuracy: 0.001)
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

    // MARK: - Ear Training Tests

    func testEarTrainingInitializer() {
        let stat = CharacterStat(earTrainingAttempts: 15, earTrainingCorrect: 12)

        XCTAssertEqual(stat.earTrainingAttempts, 15)
        XCTAssertEqual(stat.earTrainingCorrect, 12)
        XCTAssertEqual(stat.receiveAttempts, 0)
        XCTAssertEqual(stat.sendAttempts, 0)
    }

    func testEarTrainingAccuracyWithNoAttempts() {
        let stat = CharacterStat()

        XCTAssertEqual(stat.earTrainingAccuracy, 0)
    }

    func testEarTrainingAccuracyCalculation() {
        let stat = CharacterStat(earTrainingAttempts: 10, earTrainingCorrect: 7)

        XCTAssertEqual(stat.earTrainingAccuracy, 0.7, accuracy: 0.001)
    }

    func testTotalAttemptsIncludesEarTraining() {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 8,
            sendAttempts: 5, sendCorrect: 4,
            earTrainingAttempts: 8, earTrainingCorrect: 6
        )

        XCTAssertEqual(stat.totalAttempts, 23)
        XCTAssertEqual(stat.totalCorrect, 18)
    }

    func testMergeIncludesEarTraining() {
        var stat1 = CharacterStat(earTrainingAttempts: 10, earTrainingCorrect: 8)
        let stat2 = CharacterStat(earTrainingAttempts: 5, earTrainingCorrect: 4)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.earTrainingAttempts, 15)
        XCTAssertEqual(stat1.earTrainingCorrect, 12)
    }

    func testMergeUpdatesLastPracticedToLaterDate() throws {
        let earlierDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let laterDate = Date()

        var stat1 = CharacterStat(receiveAttempts: 5, receiveCorrect: 4, lastPracticed: earlierDate)
        let stat2 = CharacterStat(receiveAttempts: 5, receiveCorrect: 4, lastPracticed: laterDate)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.lastPracticed, laterDate)
    }

    func testMergeKeepsLastPracticedIfNewer() throws {
        let earlierDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let laterDate = Date()

        var stat1 = CharacterStat(receiveAttempts: 5, receiveCorrect: 4, lastPracticed: laterDate)
        let stat2 = CharacterStat(receiveAttempts: 5, receiveCorrect: 4, lastPracticed: earlierDate)

        stat1.merge(stat2)

        XCTAssertEqual(stat1.lastPracticed, laterDate)
    }

    // MARK: - Codable Tests

    func testEncodingDecodingPreservesEarTraining() throws {
        let stat = CharacterStat(
            receiveAttempts: 10, receiveCorrect: 8,
            sendAttempts: 5, sendCorrect: 4,
            earTrainingAttempts: 7, earTrainingCorrect: 6
        )

        let encoded = try JSONEncoder().encode(stat)
        let decoded = try JSONDecoder().decode(CharacterStat.self, from: encoded)

        XCTAssertEqual(decoded.earTrainingAttempts, 7)
        XCTAssertEqual(decoded.earTrainingCorrect, 6)
    }

    func testDecodingLegacyDataDefaultsEarTrainingToZero() throws {
        // Simulate legacy JSON without ear training fields
        let legacyJson = """
        {
            "receiveAttempts": 10,
            "receiveCorrect": 8,
            "sendAttempts": 5,
            "sendCorrect": 4,
            "lastPracticed": 0
        }
        """
        let data = try XCTUnwrap(legacyJson.data(using: .utf8))

        let decoded = try JSONDecoder().decode(CharacterStat.self, from: data)

        XCTAssertEqual(decoded.earTrainingAttempts, 0)
        XCTAssertEqual(decoded.earTrainingCorrect, 0)
        XCTAssertEqual(decoded.receiveAttempts, 10)
    }
}
