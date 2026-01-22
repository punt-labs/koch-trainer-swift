@testable import KochTrainer
import XCTest

@MainActor
final class ProgressStoreScheduleTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStoreSchedule")
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreSchedule")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreSchedule")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Recalculate Schedule Tests

    func testRecalculateScheduleFromHistoryWithReceiveSession() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record a receive session
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92, // 92% - should double interval
            characterStats: [:]
        )
        store.recordSession(result)

        // Clear next date to simulate needing recalculation
        var progress = store.progress
        progress.schedule.receiveNextDate = nil
        store.save(progress)

        // Recalculate
        store.recalculateScheduleFromHistory()

        XCTAssertNotNil(store.progress.schedule.receiveNextDate)
    }

    func testRecalculateScheduleFromHistoryWithSendSession() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record a send session
        let result = SessionResult(
            sessionType: .send,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92,
            characterStats: [:]
        )
        store.recordSession(result)

        // Clear next date
        var progress = store.progress
        progress.schedule.sendNextDate = nil
        store.save(progress)

        store.recalculateScheduleFromHistory()

        XCTAssertNotNil(store.progress.schedule.sendNextDate)
    }

    func testRecalculateScheduleFromHistoryIgnoresCustomSessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record only custom sessions
        let result = SessionResult(
            sessionType: .receiveCustom,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92,
            characterStats: [:]
        )
        store.recordSession(result)

        store.recalculateScheduleFromHistory()

        // Should have no next date since custom sessions don't count
        XCTAssertNil(store.progress.schedule.receiveNextDate)
    }

    func testRecalculateScheduleFromHistoryIgnoresVocabularySessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record only vocabulary sessions
        let result = SessionResult(
            sessionType: .receiveVocabulary,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92,
            characterStats: [:]
        )
        store.recordSession(result)

        store.recalculateScheduleFromHistory()

        XCTAssertNil(store.progress.schedule.receiveNextDate)
    }

    func testRecalculateScheduleFromHistoryIgnoresQSOSessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record only QSO sessions
        let result = SessionResult(
            sessionType: .qso,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92,
            characterStats: [:]
        )
        store.recordSession(result)

        store.recalculateScheduleFromHistory()

        XCTAssertNil(store.progress.schedule.sendNextDate)
    }

    func testRecalculateScheduleFromHistoryIgnoresZeroAttemptSessions() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record invalid session
        let result = SessionResult(
            sessionType: .receive,
            duration: 0,
            totalAttempts: 0,
            correctCount: 0,
            characterStats: [:]
        )
        store.recordSession(result)

        store.recalculateScheduleFromHistory()

        XCTAssertNil(store.progress.schedule.receiveNextDate)
    }

    func testRecalculateScheduleFromHistoryUsesMostRecentSession() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        // Record older session with low accuracy
        let oldResult = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 50, // 50% - would reset interval
            characterStats: [:],
            date: Date().addingTimeInterval(-86400) // Yesterday
        )
        store.recordSession(oldResult)

        // Record newer session with high accuracy
        let newResult = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95, // 95% - would double interval
            characterStats: [:],
            date: Date()
        )
        store.recordSession(newResult)

        // Clear schedule
        var progress = store.progress
        progress.schedule.receiveNextDate = nil
        progress.schedule.receiveInterval = 1.0
        store.save(progress)

        store.recalculateScheduleFromHistory()

        // Interval should be based on newer session (high accuracy = doubled)
        XCTAssertGreaterThan(store.progress.schedule.receiveInterval, 1.0)
    }

    // MARK: - Schedule Update on Level Advance Tests

    func testRecordSessionSchedulesLevelReviewOnAdvance() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95, // Advances level
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(store.progress.receiveLevel, 2)
        XCTAssertNotNil(store.progress.schedule.levelReviewDates[2])
    }
}
