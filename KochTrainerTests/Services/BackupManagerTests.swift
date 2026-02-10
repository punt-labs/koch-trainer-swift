@testable import KochTrainer
import XCTest

@MainActor
final class BackupManagerTests: XCTestCase {

    var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestBackupManager")
        testDefaults?.removePersistentDomain(forName: "TestBackupManager")
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: "TestBackupManager")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - hasBackups Tests

    func testHasBackupsReturnsFalseWhenEmpty() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)

        XCTAssertFalse(manager.hasBackups)
    }

    func testHasBackupsReturnsTrueAfterBackup() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let data = Data("test".utf8)

        manager.createBackup(from: data)

        XCTAssertTrue(manager.hasBackups)
    }

    // MARK: - createBackup Tests

    func testCreateBackupStoresDataAtIndex0() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let data = Data("test data".utf8)

        manager.createBackup(from: data)

        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0], data)
    }

    func testCreateBackupRotatesExistingBackups() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let data1 = Data("first".utf8)
        let data2 = Data("second".utf8)
        let data3 = Data("third".utf8)

        manager.createBackup(from: data1)
        manager.createBackup(from: data2)
        manager.createBackup(from: data3)

        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 3)
        XCTAssertEqual(backups[0], data3) // Newest at index 0
        XCTAssertEqual(backups[1], data2)
        XCTAssertEqual(backups[2], data1) // Oldest at index 2
    }

    func testCreateBackupDropsOldestWhenAtMax() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults, maxBackups: 3)
        let data1 = Data("first".utf8)
        let data2 = Data("second".utf8)
        let data3 = Data("third".utf8)
        let data4 = Data("fourth".utf8)

        manager.createBackup(from: data1)
        manager.createBackup(from: data2)
        manager.createBackup(from: data3)
        manager.createBackup(from: data4)

        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 3)
        XCTAssertEqual(backups[0], data4) // Newest
        XCTAssertEqual(backups[1], data3)
        XCTAssertEqual(backups[2], data2)
        // data1 was dropped
    }

    // MARK: - getBackups Tests

    func testGetBackupsReturnsEmptyArrayWhenNoBackups() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)

        let backups = manager.getBackups()

        XCTAssertTrue(backups.isEmpty)
    }

    func testGetBackupsReturnsBackupsInOrder() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let data1 = Data("one".utf8)
        let data2 = Data("two".utf8)

        manager.createBackup(from: data1)
        manager.createBackup(from: data2)

        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 2)
        XCTAssertEqual(backups[0], data2) // Newest first
        XCTAssertEqual(backups[1], data1)
    }

    // MARK: - clearBackups Tests

    func testClearBackupsRemovesAllBackups() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        manager.createBackup(from: Data("first".utf8))
        manager.createBackup(from: Data("second".utf8))
        manager.createBackup(from: Data("third".utf8))

        manager.clearBackups()

        XCTAssertFalse(manager.hasBackups)
        XCTAssertTrue(manager.getBackups().isEmpty)
    }

    func testClearBackupsWhenAlreadyEmpty() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)

        manager.clearBackups() // Should not crash

        XCTAssertFalse(manager.hasBackups)
    }

    // MARK: - Custom maxBackups Tests

    func testCustomMaxBackupsLimitsStorage() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults, maxBackups: 2)
        let data1 = Data("one".utf8)
        let data2 = Data("two".utf8)
        let data3 = Data("three".utf8)

        manager.createBackup(from: data1)
        manager.createBackup(from: data2)
        manager.createBackup(from: data3)

        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 2)
        XCTAssertEqual(backups[0], data3)
        XCTAssertEqual(backups[1], data2)
    }

    // MARK: - Persistence Tests

    func testBackupsPersistAcrossInstances() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let data = Data("persistent data".utf8)
        let manager1 = BackupManager(defaults: defaults)
        manager1.createBackup(from: data)

        // Create new instance with same defaults
        let manager2 = BackupManager(defaults: defaults)

        XCTAssertTrue(manager2.hasBackups)
        let backups = manager2.getBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0], data)
    }

    // MARK: - Edge Cases

    func testEmptyDataBackup() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let emptyData = Data()

        manager.createBackup(from: emptyData)

        XCTAssertTrue(manager.hasBackups)
        let backups = manager.getBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0], emptyData)
    }

    func testLargeDataBackup() {
        guard let defaults = testDefaults else {
            XCTFail("Test defaults not initialized")
            return
        }
        let manager = BackupManager(defaults: defaults)
        let largeData = Data(repeating: 0x42, count: 100_000)

        manager.createBackup(from: largeData)

        XCTAssertTrue(manager.hasBackups)
        let backups = manager.getBackups()
        XCTAssertEqual(backups[0].count, 100_000)
    }
}
