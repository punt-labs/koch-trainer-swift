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

        XCTAssertEqual(store.progress.currentLevel, 1)
        XCTAssertTrue(store.progress.characterStats.isEmpty)
    }

    func testInitializationLoadsExistingData() {
        // Pre-save some progress
        var progress = StudentProgress(currentLevel: 5)
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 9)
        let data = try! JSONEncoder().encode(progress)
        testDefaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: testDefaults)

        XCTAssertEqual(store.progress.currentLevel, 5)
        XCTAssertEqual(store.progress.characterStats["K"]?.totalAttempts, 10)
    }

    // MARK: - Save Tests

    func testSaveProgress() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = StudentProgress(currentLevel: 10)
        progress.characterStats["M"] = CharacterStat(totalAttempts: 20, correctCount: 18)

        store.save(progress)

        // Verify by loading
        let data = testDefaults.data(forKey: "studentProgress")!
        let loaded = try! JSONDecoder().decode(StudentProgress.self, from: data)
        XCTAssertEqual(loaded.currentLevel, 10)
        XCTAssertEqual(loaded.characterStats["M"]?.totalAttempts, 20)
    }

    // MARK: - Reset Tests

    func testResetProgress() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = StudentProgress(currentLevel: 15)
        progress.characterStats["K"] = CharacterStat(totalAttempts: 100, correctCount: 90)
        store.save(progress)

        store.resetProgress()

        XCTAssertEqual(store.progress.currentLevel, 1)
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
                "K": CharacterStat(totalAttempts: 10, correctCount: 9),
                "M": CharacterStat(totalAttempts: 10, correctCount: 9)
            ]
        )

        store.recordSession(result)

        XCTAssertEqual(store.progress.characterStats["K"]?.totalAttempts, 10)
        XCTAssertEqual(store.progress.characterStats["M"]?.totalAttempts, 10)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
    }

    func testRecordSessionAdvancesLevel() {
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
        XCTAssertEqual(store.progress.currentLevel, 2)
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
        XCTAssertEqual(store.progress.currentLevel, 1)
    }

    // MARK: - Overall Accuracy Tests

    func testOverallAccuracyPercentage() {
        let store = ProgressStore(defaults: testDefaults)
        var progress = store.progress
        progress.characterStats["K"] = CharacterStat(totalAttempts: 10, correctCount: 8)
        progress.characterStats["M"] = CharacterStat(totalAttempts: 10, correctCount: 9)
        store.save(progress)

        // (8 + 9) / 20 = 0.85 = 85%
        XCTAssertEqual(store.overallAccuracyPercentage, 85)
    }
}
