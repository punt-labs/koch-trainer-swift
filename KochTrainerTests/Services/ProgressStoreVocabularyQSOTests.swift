@testable import KochTrainer
import XCTest

@MainActor
final class ProgressStoreVocabularyQSOTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStoreVocabQSO")
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreVocabQSO")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestProgressStoreVocabQSO")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Vocabulary Paused Session Tests

    func testReceiveVocabularyUsesReceiveSlot() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receiveVocabulary,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 8,
            totalAttempts: 12,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedReceiveSession)
        XCTAssertEqual(store.pausedReceiveSession?.correctCount, 8)
        XCTAssertEqual(store.pausedSession(for: .receiveVocabulary)?.correctCount, 8)
        XCTAssertNil(store.pausedSendSession)
    }

    func testSendVocabularyUsesSendSlot() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .sendVocabulary,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 6,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedSendSession)
        XCTAssertEqual(store.pausedSendSession?.correctCount, 6)
        XCTAssertEqual(store.pausedSession(for: .sendVocabulary)?.correctCount, 6)
        XCTAssertNil(store.pausedReceiveSession)
    }

    func testClearReceiveVocabularySession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receiveVocabulary,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 8,
            totalAttempts: 12,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        store.clearPausedSession(for: .receiveVocabulary)

        XCTAssertNil(store.pausedReceiveSession)
    }

    func testClearSendVocabularySession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .sendVocabulary,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 6,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        store.clearPausedSession(for: .sendVocabulary)

        XCTAssertNil(store.pausedSendSession)
    }

    // MARK: - QSO Paused Session Tests

    func testQSOUsesSendSlot() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .qso,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 20,
            totalAttempts: 25,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedSendSession)
        XCTAssertEqual(store.pausedSendSession?.correctCount, 20)
        XCTAssertEqual(store.pausedSession(for: .qso)?.correctCount, 20)
    }

    func testClearQSOSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .qso,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 20,
            totalAttempts: 25,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        store.clearPausedSession(for: .qso)

        XCTAssertNil(store.pausedSendSession)
    }
}
