import Foundation

/// Calculates and updates practice streaks.
enum StreakCalculator {
    /// Result of a streak update calculation.
    struct StreakUpdate {
        let currentStreak: Int
        let longestStreak: Int
        let lastStreakDate: Date
    }

    /// Update streak based on a new practice session.
    ///
    /// A streak continues if the user practiced yesterday or today.
    /// A streak is broken if more than one calendar day elapsed since the last practice.
    ///
    /// - Parameters:
    ///   - lastStreakDate: Date of the last session that contributed to the streak
    ///   - currentStreak: Current streak count
    ///   - longestStreak: Longest streak ever achieved
    ///   - now: Current date (for testing)
    /// - Returns: Updated streak values
    static func updateStreak(
        lastStreakDate: Date?,
        currentStreak: Int,
        longestStreak: Int,
        now: Date = Date()
    ) -> StreakUpdate {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        guard let lastDate = lastStreakDate else {
            // First session ever
            return StreakUpdate(
                currentStreak: 1,
                longestStreak: max(longestStreak, 1),
                lastStreakDate: now
            )
        }

        let lastDateStart = calendar.startOfDay(for: lastDate)

        // Same day: streak unchanged, just update the date
        if calendar.isDate(lastDateStart, inSameDayAs: todayStart) {
            return StreakUpdate(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastStreakDate: now
            )
        }

        // Check if yesterday
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return StreakUpdate(
                currentStreak: 1,
                longestStreak: max(longestStreak, 1),
                lastStreakDate: now
            )
        }

        if calendar.isDate(lastDateStart, inSameDayAs: yesterday) {
            // Consecutive day: extend streak
            let newStreak = currentStreak + 1
            return StreakUpdate(
                currentStreak: newStreak,
                longestStreak: max(longestStreak, newStreak),
                lastStreakDate: now
            )
        } else {
            // Streak broken: start over
            return StreakUpdate(
                currentStreak: 1,
                longestStreak: longestStreak,
                lastStreakDate: now
            )
        }
    }

    /// Check if the user has practiced today.
    ///
    /// - Parameter lastStreakDate: Date of the last session
    /// - Returns: true if practiced today
    static func hasPracticedToday(lastStreakDate: Date?, now: Date = Date()) -> Bool {
        guard let lastDate = lastStreakDate else { return false }
        return Calendar.current.isDate(lastDate, inSameDayAs: now)
    }

    /// Calculate days until streak breaks.
    ///
    /// - Parameter lastStreakDate: Date of the last session
    /// - Returns: Days remaining (0 = must practice today, negative = already broken)
    static func daysUntilStreakBreaks(lastStreakDate: Date?, now: Date = Date()) -> Int {
        guard let lastDate = lastStreakDate else { return 0 }

        let calendar = Calendar.current
        let lastDayStart = calendar.startOfDay(for: lastDate)
        let todayStart = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: lastDayStart, to: todayStart)
        let daysSinceLast = components.day ?? 0

        // If practiced today (0 days ago), streak is safe until tomorrow end
        // If practiced yesterday (1 day ago), must practice today
        // If 2+ days ago, streak is already broken
        return 1 - daysSinceLast
    }
}
