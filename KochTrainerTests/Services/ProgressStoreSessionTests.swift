@testable import KochTrainer
import XCTest

@MainActor
final class ProgressStoreSessionTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStoreSession")
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreSession")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreSession")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Delete Session Tests

    func testDeleteSessionRemovesFromHistory() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record two sessions
        let result1 = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [:]
        )
        let result2 = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 25,
            correctCount: 22,
            characterStats: [:]
        )
        store.recordSession(result1)
        store.recordSession(result2)

        XCTAssertEqual(store.progress.sessionHistory.count, 2)

        // Delete first session
        let sessionToDelete = store.progress.sessionHistory[0].id
        store.deleteSession(id: sessionToDelete)

        XCTAssertEqual(store.progress.sessionHistory.count, 1)
        XCTAssertFalse(store.progress.sessionHistory.contains { $0.id == sessionToDelete })
    }

    func testDeleteSessionWithNonexistentIdDoesNothing() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [:]
        )
        store.recordSession(result)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)

        // Delete with random UUID
        store.deleteSession(id: UUID())

        XCTAssertEqual(store.progress.sessionHistory.count, 1)
    }

    // MARK: - Delete Invalid Sessions Tests

    func testDeleteInvalidSessionsRemovesZeroAttemptSessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record valid session
        let validResult = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [:]
        )
        store.recordSession(validResult)

        // Record invalid session (0 attempts)
        let invalidResult = SessionResult(
            sessionType: .receive,
            duration: 0,
            totalAttempts: 0,
            correctCount: 0,
            characterStats: [:]
        )
        store.recordSession(invalidResult)

        XCTAssertEqual(store.progress.sessionHistory.count, 2)

        let deleted = store.deleteInvalidSessions()

        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
        XCTAssertEqual(store.progress.sessionHistory[0].totalAttempts, 20)
    }

    func testDeleteInvalidSessionsReturnsZeroWhenNoInvalidSessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [:]
        )
        store.recordSession(result)

        let deleted = store.deleteInvalidSessions()

        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
    }

    func testDeleteInvalidSessionsDeletesMultiple() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record valid session
        store.recordSession(SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 20,
            correctCount: 18,
            characterStats: [:]
        ))

        // Record three invalid sessions
        for _ in 0 ..< 3 {
            store.recordSession(SessionResult(
                sessionType: .send,
                duration: 0,
                totalAttempts: 0,
                correctCount: 0,
                characterStats: [:]
            ))
        }

        XCTAssertEqual(store.progress.sessionHistory.count, 4)

        let deleted = store.deleteInvalidSessions()

        XCTAssertEqual(deleted, 3)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
    }

    // MARK: - Record Session Type Tests

    func testRecordEarTrainingSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.progress.earTrainingLevel, 1)

        // Record ear training with 90%+ accuracy
        let result = SessionResult(
            sessionType: .earTraining,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(store.progress.earTrainingLevel, 2)
        // Ear training should not affect receive/send levels
        XCTAssertEqual(store.progress.receiveLevel, 1)
        XCTAssertEqual(store.progress.sendLevel, 1)
    }

    func testRecordEarTrainingDoesNotAdvanceBelowThreshold() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .earTraining,
            duration: 300,
            totalAttempts: 100,
            correctCount: 85, // 85% < 90%
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.earTrainingLevel, 1)
    }

    func testRecordEarTrainingDoesNotAdvanceBeyondMax() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        // Pre-save progress at max ear training level
        var progress = StudentProgress()
        progress.earTrainingLevel = MorseCode.maxEarTrainingLevel
        let data = try JSONEncoder().encode(progress)
        defaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.progress.earTrainingLevel, MorseCode.maxEarTrainingLevel)

        let result = SessionResult(
            sessionType: .earTraining,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.earTrainingLevel, MorseCode.maxEarTrainingLevel)
    }

    func testRecordCustomReceiveSessionDoesNotAdvanceLevel() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .receiveCustom,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95, // Would normally advance
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.receiveLevel, 1)
    }

    func testRecordCustomSendSessionDoesNotAdvanceLevel() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .sendCustom,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.sendLevel, 1)
    }

    func testRecordVocabularyReceiveSessionDoesNotAdvanceLevel() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .receiveVocabulary,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.receiveLevel, 1)
    }

    func testRecordVocabularySendSessionDoesNotAdvanceLevel() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .sendVocabulary,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.sendLevel, 1)
    }

    func testRecordQSOSessionDoesNotAdvanceLevel() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .qso,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.sendLevel, 1)
    }

    func testEarTrainingDoesNotUpdateScheduleOrStreak() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let initialSchedule = store.progress.schedule
        let result = SessionResult(
            sessionType: .earTraining,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95,
            characterStats: [:]
        )

        store.recordSession(result)

        // Schedule should be unchanged
        XCTAssertEqual(store.progress.schedule.receiveInterval, initialSchedule.receiveInterval)
        XCTAssertEqual(store.progress.schedule.sendInterval, initialSchedule.sendInterval)
        XCTAssertEqual(store.progress.schedule.currentStreak, initialSchedule.currentStreak)
    }
}
