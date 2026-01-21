import Foundation

/// Tracks spaced repetition intervals and streak data for practice sessions.
struct PracticeSchedule: Codable, Equatable {

    // MARK: Lifecycle

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

    // MARK: Internal

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

    /// Get next practice date for a session type
    func nextDate(for sessionType: BaseSessionType) -> Date? {
        switch sessionType {
        case .receive: return receiveNextDate
        case .send: return sendNextDate
        }
    }

    /// Get interval for a session type
    func interval(for sessionType: BaseSessionType) -> Double {
        switch sessionType {
        case .receive: return receiveInterval
        case .send: return sendInterval
        }
    }

    /// Set next practice date for a session type
    mutating func setNextDate(_ date: Date?, for sessionType: BaseSessionType) {
        switch sessionType {
        case .receive: receiveNextDate = date
        case .send: sendNextDate = date
        }
    }

    /// Set interval for a session type
    mutating func setInterval(_ interval: Double, for sessionType: BaseSessionType) {
        switch sessionType {
        case .receive: receiveInterval = interval
        case .send: sendInterval = interval
        }
    }
}
