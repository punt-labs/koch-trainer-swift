import Foundation

/// Protocol for progress persistence.
protocol ProgressStoreProtocol: AnyObject {
    var progress: StudentProgress { get set }
    func load() -> StudentProgress
    func save(_ progress: StudentProgress)
    func resetProgress()
}

/// Manages persistence of student progress to UserDefaults.
@MainActor
final class ProgressStore: ObservableObject, ProgressStoreProtocol {
    @Published var progress: StudentProgress

    private let key = "studentProgress"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.progress = StudentProgress()
        self.progress = load()
    }

    func load() -> StudentProgress {
        guard let data = defaults.data(forKey: key) else {
            return StudentProgress()
        }
        do {
            return try JSONDecoder().decode(StudentProgress.self, from: data)
        } catch {
            print("Failed to decode progress: \(error)")
            return StudentProgress()
        }
    }

    func save(_ progress: StudentProgress) {
        do {
            let data = try JSONEncoder().encode(progress)
            defaults.set(data, forKey: key)
            self.progress = progress
        } catch {
            print("Failed to encode progress: \(error)")
        }
    }

    func resetProgress() {
        let fresh = StudentProgress()
        save(fresh)
    }

    /// Overall accuracy as a whole percentage (0-100)
    var overallAccuracyPercentage: Int {
        Int((progress.overallAccuracy * 100).rounded())
    }

    /// Update progress after a session and check for level advancement.
    /// Returns true if the student leveled up.
    @discardableResult
    func recordSession(_ result: SessionResult) -> Bool {
        var updated = progress
        updated.updateStats(from: result)
        let didAdvance = updated.advanceIfEligible(sessionAccuracy: result.accuracy, sessionType: result.sessionType)

        // Update schedule
        updateSchedule(for: &updated, result: result, didAdvance: didAdvance)

        save(updated)
        return didAdvance
    }

    /// Update the practice schedule based on session result.
    private func updateSchedule(for progress: inout StudentProgress, result: SessionResult, didAdvance: Bool) {
        let sessionType = result.sessionType
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
