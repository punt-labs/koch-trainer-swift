import XCTest
@testable import KochTrainer

@MainActor
final class ProgressStoreTests: XCTestCase {

    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStore")!
        testDefaults.removePersistentDomain(forName: "TestProgressStore")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "TestProgressStore")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithEmptyDefaults() {
        let store = ProgressStore(defaults: testDefaults)

        XCTAssertEqual(store.progress.receiveLevel, 1)
        XCTAssertEqual(store.progress.sendLevel, 1)
        XCTAssertTrue(store.progress.characterStats.isEmpty)
    }

    func testInitializationLoadsExistingData() {
        // Pre-save some progress
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
        let data = try! JSONEncoder().encode(progress)
        testDefaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: testDefaults)

        XCTAssertEqual(store.progress.receiveLevel, 5)
        XCTAssertEqual(store.progress.sendLevel, 3)
        XCTAssertEqual(store.progress.characterStats["K"]?.receiveAttempts, 10)
    }

    // MARK: - Save Tests

    func testSaveProgress() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = StudentProgress(receiveLevel: 10, sendLevel: 7)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 20, receiveCorrect: 18)

        store.save(progress)

        // Verify by loading
        let data = testDefaults.data(forKey: "studentProgress")!
        let loaded = try! JSONDecoder().decode(StudentProgress.self, from: data)
        XCTAssertEqual(loaded.receiveLevel, 10)
        XCTAssertEqual(loaded.sendLevel, 7)
        XCTAssertEqual(loaded.characterStats["M"]?.receiveAttempts, 20)
    }

    // MARK: - Reset Tests

    func testResetProgress() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = StudentProgress(receiveLevel: 15, sendLevel: 10)
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 100, receiveCorrect: 90)
        store.save(progress)

        store.resetProgress()

        XCTAssertEqual(store.progress.receiveLevel, 1)
        XCTAssertEqual(store.progress.sendLevel, 1)
        XCTAssertTrue(store.progress.characterStats.isEmpty)
    }

    // MARK: - Record Session Tests

    func testRecordSessionUpdatesStats() {
        let store = ProgressStore(defaults: testDefaults)
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

        store.recordSession(result)

        XCTAssertEqual(store.progress.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(store.progress.characterStats["M"]?.receiveAttempts, 10)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
    }

    func testRecordReceiveSessionAdvancesReceiveLevel() {
        let store = ProgressStore(defaults: testDefaults)
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 95, // 95% > 90%
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(store.progress.receiveLevel, 2)
        XCTAssertEqual(store.progress.sendLevel, 1) // Unchanged
    }

    func testRecordSendSessionAdvancesSendLevel() {
        let store = ProgressStore(defaults: testDefaults)
        let result = SessionResult(
            sessionType: .send,
            duration: 300,
            totalAttempts: 100,
            correctCount: 92, // 92% > 90%
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(store.progress.sendLevel, 2)
        XCTAssertEqual(store.progress.receiveLevel, 1) // Unchanged
    }

    func testRecordSessionDoesNotAdvanceBelowThreshold() {
        let store = ProgressStore(defaults: testDefaults)
        let result = SessionResult(
            sessionType: .receive,
            duration: 300,
            totalAttempts: 100,
            correctCount: 85, // 85% < 90%
            characterStats: [:]
        )

        let didAdvance = store.recordSession(result)

        XCTAssertFalse(didAdvance)
        XCTAssertEqual(store.progress.receiveLevel, 1)
    }

    // MARK: - Overall Accuracy Tests

    func testOverallAccuracyPercentage() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = store.progress
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
        store.save(progress)

        // (8 + 9) / 20 = 0.85 = 85%
        XCTAssertEqual(store.overallAccuracyPercentage, 85)
    }
}
