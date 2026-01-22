import Foundation
import OSLog

// MARK: - ProgressStoreProtocol

/// Protocol for progress persistence.
@MainActor
protocol ProgressStoreProtocol: AnyObject {
    var progress: StudentProgress { get set }
    func load() -> StudentProgress
    func save(_ progress: StudentProgress)
    func resetProgress()

    // Paused session management
    var pausedReceiveSession: PausedSession? { get }
    var pausedSendSession: PausedSession? { get }
    var pausedEarTrainingSession: PausedSession? { get }
    func savePausedSession(_ session: PausedSession)
    func clearPausedSession(for sessionType: SessionType)
    func pausedSession(for sessionType: SessionType) -> PausedSession?
}

// MARK: - ProgressStore

/// Manages persistence of student progress to UserDefaults.
@MainActor
final class ProgressStore: ObservableObject, ProgressStoreProtocol {

    // MARK: Lifecycle

    init(defaults: UserDefaults = .standard, backupManager: BackupManager? = nil) {
        self.defaults = defaults
        self.backupManager = backupManager ?? BackupManager(defaults: defaults)
        progress = StudentProgress()
        progress = load()
        loadPausedSessions()
    }

    // MARK: Internal

    @Published var progress: StudentProgress
    @Published private(set) var pausedReceiveSession: PausedSession?
    @Published private(set) var pausedSendSession: PausedSession?
    @Published private(set) var pausedEarTrainingSession: PausedSession?

    /// Overall accuracy as a whole percentage (0-100)
    var overallAccuracyPercentage: Int {
        Int((progress.overallAccuracy * 100).rounded())
    }

    func load() -> StudentProgress {
        guard let data = defaults.data(forKey: key) else {
            return StudentProgress()
        }

        // Try primary data with graceful decode
        if let progress = GracefulDecoder.decode(from: data) {
            return progress
        }

        // Primary failed completely, try backups
        logger.warning("Primary decode failed, attempting backup recovery")
        for (index, backupData) in backupManager.getBackups().enumerated() {
            if let progress = GracefulDecoder.decode(from: backupData) {
                logger.notice("Recovered from backup \(index)")
                return progress
            }
        }

        // All decode attempts failed
        logger.error("All decode attempts failed, returning fresh progress")
        return StudentProgress()
    }

    func save(_ progress: StudentProgress) {
        do {
            let data = try JSONEncoder().encode(progress)

            // Create backup of existing data before overwriting
            if let existingData = defaults.data(forKey: key) {
                backupManager.createBackup(from: existingData)
            }

            defaults.set(data, forKey: key)
            self.progress = progress
        } catch {
            logger.error("Failed to encode progress: \(error.localizedDescription)")
        }
    }

    func resetProgress() {
        backupManager.clearBackups() // Clear backups on intentional reset
        defaults.removeObject(forKey: key) // Remove existing data so save() doesn't backup
        let fresh = StudentProgress()
        save(fresh)
    }

    /// Delete a specific session from history.
    ///
    /// - Warning: This removes the session but does not recalculate intervals or streaks.
    ///   If the deleted session affected the schedule, call `recalculateScheduleFromHistory()`
    ///   afterward to restore consistency.
    func deleteSession(id: UUID) {
        var updated = progress
        updated.sessionHistory.removeAll { $0.id == id }
        save(updated)
    }

    /// Delete all sessions with zero attempts (invalid/cancelled sessions).
    /// Returns the number of sessions deleted.
    @discardableResult
    func deleteInvalidSessions() -> Int {
        var updated = progress
        let before = updated.sessionHistory.count
        updated.sessionHistory.removeAll { $0.totalAttempts == 0 }
        let deleted = before - updated.sessionHistory.count
        if deleted > 0 {
            save(updated)
        }
        return deleted
    }

    /// Recalculate next practice dates based on most recent valid Learn session for each type.
    /// Only considers standard receive/send sessions, not Custom, Vocabulary, or QSO.
    func recalculateScheduleFromHistory() {
        var updated = progress

        // Find most recent valid Learn session for each type
        // Only sessions that can advance level affect the schedule
        let learnSessions = updated.sessionHistory.filter {
            $0.totalAttempts > 0 && $0.sessionType.canAdvanceLevel
        }

        let lastReceive = learnSessions
            .filter { $0.sessionType.baseType == .receive }
            .max { $0.date < $1.date }

        let lastSend = learnSessions
            .filter { $0.sessionType.baseType == .send }
            .max { $0.date < $1.date }

        // Recalculate receive schedule
        if let session = lastReceive {
            let daysSinceStart = Int(session.date.timeIntervalSince(updated.startDate) / 86400)
            let newInterval = IntervalCalculator.calculateNextInterval(
                currentInterval: updated.schedule.receiveInterval,
                accuracy: session.accuracy,
                daysSinceStart: daysSinceStart
            )
            updated.schedule.receiveInterval = newInterval
            updated.schedule.receiveNextDate = IntervalCalculator.nextPracticeDate(
                interval: newInterval,
                from: session.date
            )
        } else {
            updated.schedule.receiveNextDate = nil
        }

        // Recalculate send schedule
        if let session = lastSend {
            let daysSinceStart = Int(session.date.timeIntervalSince(updated.startDate) / 86400)
            let newInterval = IntervalCalculator.calculateNextInterval(
                currentInterval: updated.schedule.sendInterval,
                accuracy: session.accuracy,
                daysSinceStart: daysSinceStart
            )
            updated.schedule.sendInterval = newInterval
            updated.schedule.sendNextDate = IntervalCalculator.nextPracticeDate(
                interval: newInterval,
                from: session.date
            )
        } else {
            updated.schedule.sendNextDate = nil
        }

        save(updated)
    }

    /// Update progress after a session and check for level advancement.
    /// Returns true if the student leveled up.
    @discardableResult
    func recordSession(_ result: SessionResult) -> Bool {
        var updated = progress
        updated.updateStats(from: result)

        let didAdvance: Bool

        // Ear training has its own level progression (1-5) and doesn't affect schedule/streaks
        if result.sessionType == .earTraining {
            didAdvance = advanceEarTrainingIfEligible(&updated, accuracy: result.accuracy)
            // No schedule/streak updates for ear training
        } else if result.sessionType.canAdvanceLevel {
            // Standard receive/send sessions
            didAdvance = updated.advanceIfEligible(
                sessionAccuracy: result.accuracy,
                sessionType: result.sessionType.baseType
            )
            updateSchedule(for: &updated, result: result, didAdvance: didAdvance)
        } else {
            // Custom, Vocabulary, QSO - no advancement or schedule changes
            didAdvance = false
        }

        save(updated)
        return didAdvance
    }

    // MARK: - Paused Session Management

    func savePausedSession(_ session: PausedSession) {
        do {
            let data = try JSONEncoder().encode(session)
            let key = pausedSessionKey(for: session.sessionType)
            defaults.set(data, forKey: key)

            switch session.sessionType {
            case .earTraining:
                pausedEarTrainingSession = session
            case .receive,
                 .receiveCustom,
                 .receiveVocabulary:
                pausedReceiveSession = session
            case .send,
                 .sendCustom,
                 .sendVocabulary,
                 .qso:
                pausedSendSession = session
            }
        } catch {
            print("Failed to encode paused session: \(error)")
        }
    }

    func clearPausedSession(for sessionType: SessionType) {
        let key = pausedSessionKey(for: sessionType)
        defaults.removeObject(forKey: key)

        switch sessionType {
        case .earTraining:
            pausedEarTrainingSession = nil
        case .receive,
             .receiveCustom,
             .receiveVocabulary:
            pausedReceiveSession = nil
        case .send,
             .sendCustom,
             .sendVocabulary,
             .qso:
            pausedSendSession = nil
        }
    }

    func pausedSession(for sessionType: SessionType) -> PausedSession? {
        switch sessionType {
        case .earTraining:
            return pausedEarTrainingSession
        case .receive,
             .receiveCustom,
             .receiveVocabulary:
            return pausedReceiveSession
        case .send,
             .sendCustom,
             .sendVocabulary,
             .qso:
            return pausedSendSession
        }
    }

    // MARK: Private

    private let key = "studentProgress"
    private let pausedReceiveKey = "pausedReceiveSession"
    private let pausedSendKey = "pausedSendSession"
    private let pausedEarTrainingKey = "pausedEarTrainingSession"
    private let defaults: UserDefaults
    private let backupManager: BackupManager
    private let logger = Logger(subsystem: "com.kochtrainer", category: "ProgressStore")

    /// Check and advance ear training level if eligible.
    /// Requires ≥90% accuracy with sufficient attempts.
    private func advanceEarTrainingIfEligible(_ progress: inout StudentProgress, accuracy: Double) -> Bool {
        guard accuracy >= 0.90 else { return false }
        guard progress.earTrainingLevel < MorseCode.maxEarTrainingLevel else { return false }
        progress.earTrainingLevel += 1
        return true
    }

    private func pausedSessionKey(for sessionType: SessionType) -> String {
        switch sessionType {
        case .earTraining:
            return pausedEarTrainingKey
        case .receive,
             .receiveCustom,
             .receiveVocabulary:
            return pausedReceiveKey
        case .send,
             .sendCustom,
             .sendVocabulary,
             .qso:
            return pausedSendKey
        }
    }

    private func loadPausedSessions() {
        pausedReceiveSession = loadPausedSession(forKey: pausedReceiveKey)
        pausedSendSession = loadPausedSession(forKey: pausedSendKey)
        pausedEarTrainingSession = loadPausedSession(forKey: pausedEarTrainingKey)

        // Clear expired sessions
        if let receive = pausedReceiveSession, receive.isExpired {
            clearPausedSession(for: .receive)
        }
        if let send = pausedSendSession, send.isExpired {
            clearPausedSession(for: .send)
        }
        if let earTraining = pausedEarTrainingSession, earTraining.isExpired {
            clearPausedSession(for: .earTraining)
        }
    }

    private func loadPausedSession(forKey key: String) -> PausedSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(PausedSession.self, from: data)
        } catch {
            print("Failed to decode paused session: \(error)")
            return nil
        }
    }

    /// Update the practice schedule based on session result.
    private func updateSchedule(for progress: inout StudentProgress, result: SessionResult, didAdvance: Bool) {
        // Use base session type for schedule updates (receive/send, not custom variants)
        let sessionType = result.sessionType.baseType
        let now = result.date

        // Calculate days since start for interval cap
        let daysSinceStart = Int(now.timeIntervalSince(progress.startDate) / 86400)

        // Get current interval for this session type
        var currentInterval = progress.schedule.interval(for: sessionType)

        // Check if interval should reset due to missed practice
        if let lastDate = progress.schedule.lastStreakDate {
            if IntervalCalculator.shouldResetInterval(lastPractice: lastDate, interval: currentInterval, now: now) {
                currentInterval = 1.0
            }
        }

        // Calculate new interval based on session accuracy
        let newInterval = IntervalCalculator.calculateNextInterval(
            currentInterval: currentInterval,
            accuracy: result.accuracy,
            daysSinceStart: daysSinceStart
        )

        // Update interval and next practice date
        progress.schedule.setInterval(newInterval, for: sessionType)
        let nextDate = IntervalCalculator.nextPracticeDate(interval: newInterval, from: now)
        progress.schedule.setNextDate(nextDate, for: sessionType)

        // Update streak
        let streakUpdate = StreakCalculator.updateStreak(
            lastStreakDate: progress.schedule.lastStreakDate,
            currentStreak: progress.schedule.currentStreak,
            longestStreak: progress.schedule.longestStreak,
            now: now
        )
        progress.schedule.currentStreak = streakUpdate.currentStreak
        progress.schedule.longestStreak = streakUpdate.longestStreak
        progress.schedule.lastStreakDate = streakUpdate.lastStreakDate

        // If level advanced, schedule a review in 7 days
        if didAdvance {
            let newLevel = progress.level(for: sessionType)
            let reviewDate = now.addingTimeInterval(7 * 86400)
            progress.schedule.levelReviewDates[newLevel] = reviewDate
        }
    }
}
