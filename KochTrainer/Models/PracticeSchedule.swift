import Foundation

/// Tracks spaced repetition intervals and streak data for practice sessions.
struct PracticeSchedule: Codable, Equatable {
    /// Days until next receive practice (starts at 1, grows with accuracy)
    var receiveInterval: Double

    /// Days until next send practice
    var sendInterval: Double

    /// Next scheduled date for receive practice
    var receiveNextDate: Date?

    /// Next scheduled date for send practice
    var sendNextDate: Date?

    /// Current consecutive days practiced
    var currentStreak: Int

    /// Longest streak ever achieved
    var longestStreak: Int

    /// Most recent date when a session contributed to the streak
    var lastStreakDate: Date?

    /// Level -> date when that level should be reviewed (refresher sessions)
    var levelReviewDates: [Int: Date]

    init(
        receiveInterval: Double = 1.0,
        sendInterval: Double = 1.0,
        receiveNextDate: Date? = nil,
        sendNextDate: Date? = nil,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastStreakDate: Date? = nil,
        levelReviewDates: [Int: Date] = [:]
    ) {
        self.receiveInterval = receiveInterval
        self.sendInterval = sendInterval
        self.receiveNextDate = receiveNextDate
        self.sendNextDate = sendNextDate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastStreakDate = lastStreakDate
        self.levelReviewDates = levelReviewDates
    }

    /// Get next practice date for a session type (uses base type for custom/vocabulary)
    func nextDate(for sessionType: SessionType) -> Date? {
        switch sessionType.baseType {
        case .receive: return receiveNextDate
        case .send: return sendNextDate
        default: return nil
        }
    }

    /// Get interval for a session type (uses base type for custom/vocabulary)
    func interval(for sessionType: SessionType) -> Double {
        switch sessionType.baseType {
        case .receive: return receiveInterval
        case .send: return sendInterval
        default: return 1.0
        }
    }

    /// Set next practice date for a session type (uses base type for custom/vocabulary)
    mutating func setNextDate(_ date: Date?, for sessionType: SessionType) {
        switch sessionType.baseType {
        case .receive: receiveNextDate = date
        case .send: sendNextDate = date
        default: break
        }
    }

    /// Set interval for a session type (uses base type for custom/vocabulary)
    mutating func setInterval(_ interval: Double, for sessionType: SessionType) {
        switch sessionType.baseType {
        case .receive: receiveInterval = interval
        case .send: sendInterval = interval
        default: break
        }
    }
}
