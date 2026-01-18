import Foundation

/// Calculates spaced repetition intervals based on performance.
enum IntervalCalculator {
    /// Calculate the next practice interval based on session performance.
    ///
    /// - Parameters:
    ///   - currentInterval: Current interval in days
    ///   - accuracy: Session accuracy (0.0 to 1.0)
    ///   - daysSinceStart: Days since user began training
    /// - Returns: New interval in days
    static func calculateNextInterval(
        currentInterval: Double,
        accuracy: Double,
        daysSinceStart: Int
    ) -> Double {
        // During habit formation (first 14 days), cap at 2 days
        // After habit formation, allow up to 30 days
        let maxInterval = daysSinceStart < 14 ? 2.0 : 30.0

        if accuracy >= 0.90 {
            // High performance: double the interval
            return min(currentInterval * 2.0, maxInterval)
        } else if accuracy >= 0.70 {
            // Medium performance: maintain current interval
            return currentInterval
        } else {
            // Low performance: reset to daily practice
            return 1.0
        }
    }

    /// Determines if the interval should reset due to missed practice.
    ///
    /// If the user misses more than 2× their current interval, reset to daily.
    ///
    /// - Parameters:
    ///   - lastPractice: Date of last practice session
    ///   - interval: Current interval in days
    ///   - now: Current date (for testing)
    /// - Returns: true if interval should be reset
    static func shouldResetInterval(
        lastPractice: Date,
        interval: Double,
        now: Date = Date()
    ) -> Bool {
        let elapsed = now.timeIntervalSince(lastPractice) / 86400.0
        return elapsed > interval * 2.0
    }

    /// Calculate next practice date from current interval.
    ///
    /// - Parameters:
    ///   - interval: Interval in days
    ///   - from: Starting date
    /// - Returns: Next practice date
    static func nextPracticeDate(
        interval: Double,
        from date: Date = Date()
    ) -> Date {
        date.addingTimeInterval(interval * 86400)
    }
}
