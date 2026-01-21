// swiftlint:disable type_body_length
@testable import KochTrainer
import XCTest

@MainActor
final class ProgressStoreTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestProgressStore")
        testDefaults?.removePersistentDomain(forName: "TestProgressStore")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestProgressStore")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithEmptyDefaults() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        XCTAssertEqual(store.progress.receiveLevel, 1)
        XCTAssertEqual(store.progress.sendLevel, 1)
        XCTAssertTrue(store.progress.characterStats.isEmpty)
    }

    func testInitializationLoadsExistingData() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        // Pre-save some progress
        var progress = StudentProgress(receiveLevel: 5, sendLevel: 3)
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
        let data = try JSONEncoder().encode(progress)
        defaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: defaults)

        XCTAssertEqual(store.progress.receiveLevel, 5)
        XCTAssertEqual(store.progress.sendLevel, 3)
        XCTAssertEqual(store.progress.characterStats["K"]?.receiveAttempts, 10)
    }

    // MARK: - Save Tests

    func testSaveProgress() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        var progress = StudentProgress(receiveLevel: 10, sendLevel: 7)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 20, receiveCorrect: 18)

        store.save(progress)

        // Verify by loading
        guard let data = defaults.data(forKey: "studentProgress") else {
            XCTFail("No data saved")
            return
        }
        let loaded = try JSONDecoder().decode(StudentProgress.self, from: data)
        XCTAssertEqual(loaded.receiveLevel, 10)
        XCTAssertEqual(loaded.sendLevel, 7)
        XCTAssertEqual(loaded.characterStats["M"]?.receiveAttempts, 20)
    }

    // MARK: - Reset Tests

    func testResetProgress() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
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
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
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
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
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
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
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
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        var progress = store.progress
        progress.characterStats["K"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 8)
        progress.characterStats["M"] = CharacterStat(receiveAttempts: 10, receiveCorrect: 9)
        store.save(progress)

        // (8 + 9) / 20 = 0.85 = 85%
        XCTAssertEqual(store.overallAccuracyPercentage, 85)
    }

    // MARK: - Paused Session Tests

    func testSavePausedReceiveSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["K", "M"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 2
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedReceiveSession)
        XCTAssertEqual(store.pausedReceiveSession?.correctCount, 10)
        XCTAssertEqual(store.pausedReceiveSession?.currentLevel, 2)
    }

    func testSavePausedSendSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .send,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 8,
            characterStats: [:],
            introCharacters: ["K"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )

        store.savePausedSession(session)

        XCTAssertNotNil(store.pausedSendSession)
        XCTAssertEqual(store.pausedSendSession?.correctCount, 5)
        XCTAssertNil(store.pausedReceiveSession)
    }

    func testClearPausedReceiveSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        store.clearPausedSession(for: .receive)

        XCTAssertNil(store.pausedReceiveSession)
    }

    func testClearPausedSendSession() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .send,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 8,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        store.clearPausedSession(for: .send)

        XCTAssertNil(store.pausedSendSession)
    }

    func testPausedSessionForReceive() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 1
        )
        store.savePausedSession(session)

        let retrieved = store.pausedSession(for: .receive)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.correctCount, 10)
    }

    func testPausedSessionForSend() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .send,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 7,
            totalAttempts: 12,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )
        store.savePausedSession(session)

        let retrieved = store.pausedSession(for: .send)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.correctCount, 7)
        XCTAssertNil(store.pausedSession(for: .receive))
    }

    func testPausedSessionPersistsAcrossInstances() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store1 = ProgressStore(defaults: defaults)
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 20,
            totalAttempts: 25,
            characterStats: ["K": CharacterStat(receiveAttempts: 10, receiveCorrect: 8)],
            introCharacters: ["K", "M", "R"],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 3
        )
        store1.savePausedSession(session)

        // Create new store instance
        let store2 = ProgressStore(defaults: defaults)

        XCTAssertNotNil(store2.pausedReceiveSession)
        XCTAssertEqual(store2.pausedReceiveSession?.correctCount, 20)
        XCTAssertEqual(store2.pausedReceiveSession?.introCharacters, ["K", "M", "R"])
        XCTAssertEqual(store2.pausedReceiveSession?.characterStats["K"]?.receiveAttempts, 10)
    }

    func testExpiredPausedSessionClearedOnLoad() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        // Manually save an expired session to UserDefaults
        let expiredSession = PausedSession(
            sessionType: .receive,
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
        defaults.set(data, forKey: "pausedReceiveSession")

        // Create store - should clear expired session
        let store = ProgressStore(defaults: defaults)

        XCTAssertNil(store.pausedReceiveSession)
    }

    func testBothReceiveAndSendCanBePausedSimultaneously() {
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

        store.savePausedSession(receiveSession)
        store.savePausedSession(sendSession)

        XCTAssertNotNil(store.pausedReceiveSession)
        XCTAssertNotNil(store.pausedSendSession)
        XCTAssertEqual(store.pausedReceiveSession?.correctCount, 10)
        XCTAssertEqual(store.pausedSendSession?.correctCount, 5)
    }

    func testCustomSessionTypeUsesBaseType() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)

        let customReceiveSession = PausedSession(
            sessionType: .receiveCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            characterStats: [:],
            introCharacters: ["A", "B"],
            introCompleted: true,
            customCharacters: ["A", "B"],
            currentLevel: 1
        )

        store.savePausedSession(customReceiveSession)

        // Should be stored under receive
        XCTAssertNotNil(store.pausedReceiveSession)
        XCTAssertNil(store.pausedSendSession)
        XCTAssertEqual(store.pausedSession(for: .receive)?.correctCount, 10)
        XCTAssertEqual(store.pausedSession(for: .receiveCustom)?.correctCount, 10)
    }

    // MARK: - Backup Integration Tests

    func testSaveCreatesBackup() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let backupManager = BackupManager(defaults: defaults)
        let store = ProgressStore(defaults: defaults, backupManager: backupManager)

        // Save initial progress
        let progress1 = StudentProgress(receiveLevel: 3, sendLevel: 2)
        store.save(progress1)

        // Save updated progress (should backup previous)
        let progress2 = StudentProgress(receiveLevel: 5, sendLevel: 4)
        store.save(progress2)

        // Verify backup exists
        XCTAssertTrue(backupManager.hasBackups)
        let backups = backupManager.getBackups()
        XCTAssertEqual(backups.count, 1)

        // Verify backup contains first progress
        let backupProgress = try JSONDecoder().decode(StudentProgress.self, from: backups[0])
        XCTAssertEqual(backupProgress.receiveLevel, 3)
        XCTAssertEqual(backupProgress.sendLevel, 2)
    }

    func testResetClearsBackups() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let backupManager = BackupManager(defaults: defaults)
        let store = ProgressStore(defaults: defaults, backupManager: backupManager)

        // Create some backups
        let progress1 = StudentProgress(receiveLevel: 3)
        store.save(progress1)
        let progress2 = StudentProgress(receiveLevel: 5)
        store.save(progress2)
        XCTAssertTrue(backupManager.hasBackups)

        // Reset should clear backups
        store.resetProgress()

        XCTAssertFalse(backupManager.hasBackups)
    }

    func testLoadRecoverFromBackupOnCorruptPrimary() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        // First, save valid progress to create backup
        let backupManager = BackupManager(defaults: defaults)
        let store1 = ProgressStore(defaults: defaults, backupManager: backupManager)
        let progress1 = StudentProgress(receiveLevel: 7, sendLevel: 5)
        store1.save(progress1)

        // Save again to push first save to backup
        let progress2 = StudentProgress(receiveLevel: 10, sendLevel: 8)
        store1.save(progress2)

        // Now corrupt the primary data
        defaults.set(Data("corrupted json".utf8), forKey: "studentProgress")

        // Create new store - should recover from backup
        let store2 = ProgressStore(defaults: defaults, backupManager: backupManager)

        // Should recover the first progress (from backup)
        XCTAssertEqual(store2.progress.receiveLevel, 7)
        XCTAssertEqual(store2.progress.sendLevel, 5)
    }

    func testLoadUsesGracefulDecodeForPartialData() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        // Create JSON with missing optional fields but valid core data
        let json: [String: Any] = [
            "receiveLevel": 12,
            "sendLevel": 10,
            "characterStats": [String: Any](),
            "sessionHistory": [[String: Any]](),
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        defaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: defaults)

        XCTAssertEqual(store.progress.receiveLevel, 12)
        XCTAssertEqual(store.progress.sendLevel, 10)
    }

    func testSchemaVersionPreserved() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let store = ProgressStore(defaults: defaults)
        let progress = StudentProgress(schemaVersion: 1, receiveLevel: 5)

        store.save(progress)

        // Read back and verify schema version
        guard let data = defaults.data(forKey: "studentProgress") else {
            XCTFail("No data saved")
            return
        }
        let loaded = try JSONDecoder().decode(StudentProgress.self, from: data)
        XCTAssertEqual(loaded.schemaVersion, 1)
    }

    func testMultipleBackupsRotateCorrectly() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let backupManager = BackupManager(defaults: defaults, maxBackups: 3)
        let store = ProgressStore(defaults: defaults, backupManager: backupManager)

        // Save 4 times - should have 3 backups (oldest dropped)
        store.save(StudentProgress(receiveLevel: 1))
        store.save(StudentProgress(receiveLevel: 2))
        store.save(StudentProgress(receiveLevel: 3))
        store.save(StudentProgress(receiveLevel: 4))

        let backups = backupManager.getBackups()
        XCTAssertEqual(backups.count, 3)

        // Newest backup should be level 3, oldest should be level 1
        let backup0 = try JSONDecoder().decode(StudentProgress.self, from: backups[0])
        let backup2 = try JSONDecoder().decode(StudentProgress.self, from: backups[2])
        XCTAssertEqual(backup0.receiveLevel, 3) // Most recent backup
        XCTAssertEqual(backup2.receiveLevel, 1) // Oldest backup
    }

    func testGracefulDecodeRecoverPartialSessionHistory() throws {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }

        // Create JSON with one valid session and one invalid session
        let validSession: [String: Any] = [
            "id": UUID().uuidString,
            "sessionType": "receive",
            "date": Date().timeIntervalSinceReferenceDate,
            "duration": 300.0,
            "totalAttempts": 20,
            "correctCount": 18,
            "characterStats": [String: Any]()
        ]

        let invalidSession: [String: Any] = [
            "id": "not-a-uuid",
            "sessionType": "unknown",
            "date": "invalid"
        ]

        let json: [String: Any] = [
            "receiveLevel": 5,
            "sendLevel": 3,
            "characterStats": [String: Any](),
            "sessionHistory": [validSession, invalidSession],
            "startDate": Date().timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        defaults.set(data, forKey: "studentProgress")

        let store = ProgressStore(defaults: defaults)

        // Should recover valid data and keep valid session
        XCTAssertEqual(store.progress.receiveLevel, 5)
        XCTAssertEqual(store.progress.sendLevel, 3)
        XCTAssertEqual(store.progress.sessionHistory.count, 1)
        XCTAssertEqual(store.progress.sessionHistory.first?.totalAttempts, 20)
    }
}

// swiftlint:enable type_body_length
