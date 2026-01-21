import Foundation
import OSLog

// MARK: - BackupManager

/// Manages rolling backups of StudentProgress JSON data in UserDefaults.
///
/// Maintains up to `maxBackups` copies with the most recent at index 0.
/// On each backup, older copies are rotated: 0→1, 1→2, oldest dropped.
@MainActor
final class BackupManager {

    // MARK: Lifecycle

    init(defaults: UserDefaults = .standard, maxBackups: Int = 3) {
        self.defaults = defaults
        self.maxBackups = maxBackups
    }

    // MARK: Internal

    /// Check if any backups exist.
    var hasBackups: Bool {
        (0 ..< maxBackups).contains { defaults.data(forKey: backupKey(index: $0)) != nil }
    }

    /// Create a backup before saving new data.
    /// Rotates existing backups: 0→1, 1→2, etc. Oldest is dropped.
    func createBackup(from data: Data) {
        // Rotate existing backups (oldest dropped)
        for index in stride(from: maxBackups - 1, through: 1, by: -1) {
            let sourceKey = backupKey(index: index - 1)
            let destKey = backupKey(index: index)

            if let sourceData = defaults.data(forKey: sourceKey) {
                defaults.set(sourceData, forKey: destKey)
            } else {
                defaults.removeObject(forKey: destKey)
            }
        }

        // Store new backup at index 0
        defaults.set(data, forKey: backupKey(index: 0))
        let slots = maxBackups
        logger.debug("Created backup, rotated \(slots) slots")
    }

    /// Retrieve all backups in order (newest first).
    /// Returns array of Data, may be empty if no backups exist.
    func getBackups() -> [Data] {
        var backups: [Data] = []
        for index in 0 ..< maxBackups {
            if let data = defaults.data(forKey: backupKey(index: index)) {
                backups.append(data)
            }
        }
        return backups
    }

    /// Clear all backups (used when user explicitly resets progress).
    func clearBackups() {
        for index in 0 ..< maxBackups {
            defaults.removeObject(forKey: backupKey(index: index))
        }
        logger.debug("Cleared all backups")
    }

    // MARK: Private

    private let defaults: UserDefaults
    private let maxBackups: Int
    private let keyPrefix = "studentProgress.backup."
    private let logger = Logger(subsystem: "com.kochtrainer", category: "BackupManager")

    private func backupKey(index: Int) -> String {
        "\(keyPrefix)\(index)"
    }
}
