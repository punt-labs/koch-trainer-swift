@testable import KochTrainer
import XCTest

@MainActor
final class ProgressStorePausedSessionTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStorePaused")
        testDefaults?.removePersistentDomain(forName: "TestProgressStorePaused")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestProgressStorePaused")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Ear Training Paused Session Tests

    func testSavePausedEarTrainingSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 2
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedEarTrainingSession)
        XCTAssertEqual(store.pausedEarTrainingSession?.correctCount, 15)
        XCTAssertEqual(store.pausedEarTrainingSession?.currentLevel, 2)
        // Should not affect receive or send
        XCTAssertNil(store.pausedReceiveSession)
        XCTAssertNil(store.pausedSendSession)
    }

    func testClearPausedEarTrainingSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 2
        )
        store.savePausedSession(session)
        XCTAssertNotNil(store.pausedEarTrainingSession)

        store.clearPausedSession(for: .earTraining)

        XCTAssertNil(store.pausedEarTrainingSession)
    }

    func testPausedSessionForEarTraining() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 12,
            totalAttempts: 18,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )
        store.savePausedSession(session)

        let retrieved = store.pausedSession(for: .earTraining)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.correctCount, 12)
        XCTAssertEqual(retrieved?.currentLevel, 3)
    }

    func testPausedEarTrainingSessionPersistsAcrossInstances() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store1 = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 25,
            totalAttempts: 30,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 4
        )
        store1.savePausedSession(session)

        let store2 = ProgressStore(defaults: defaults)

        XCTAssertNotNil(store2.pausedEarTrainingSession)
        XCTAssertEqual(store2.pausedEarTrainingSession?.correctCount, 25)
    }

    func testExpiredEarTrainingSessionClearedOnLoad() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        let expiredSession = PausedSession(
            sessionType: .earTraining,
            startTime: Date().addingTimeInterval(-48 * 3600),
            pausedAt: Date().addingTimeInterval(-25 * 3600), // > 24 hours ago
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        let data = try JSONEncoder().encode(expiredSession)
        defaults.set(data, forKey: "pausedEarTrainingSession")

        let store = ProgressStore(defaults: defaults)

        XCTAssertNil(store.pausedEarTrainingSession)
    }

    // MARK: - All Three Session Types Simultaneously

    func testAllThreeSessionTypesCanBePausedSimultaneously() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let receiveSession = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 2
        )

        let sendSession = PausedSession(
            sessionType: .send,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 8,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )

        let earTrainingSession = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 18,
            totalAttempts: 20,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 4
        )

        store.savePausedSession(receiveSession)
        store.savePausedSession(sendSession)
        store.savePausedSession(earTrainingSession)

        XCTAssertNotNil(store.pausedReceiveSession)
        XCTAssertNotNil(store.pausedSendSession)
        XCTAssertNotNil(store.pausedEarTrainingSession)
        XCTAssertEqual(store.pausedReceiveSession?.correctCount, 10)
        XCTAssertEqual(store.pausedSendSession?.correctCount, 5)
        XCTAssertEqual(store.pausedEarTrainingSession?.correctCount, 18)
    }
}
