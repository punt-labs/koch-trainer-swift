import Foundation

/// User preferences for notification behavior.
struct NotificationSettings: Codable, Equatable {

    // MARK: Lifecycle

    init(
        practiceRemindersEnabled: Bool = true,
        streakRemindersEnabled: Bool = true,
        preferredReminderTime: Date? = nil,
        quietHoursEnabled: Bool = true
    ) {
        self.practiceRemindersEnabled = practiceRemindersEnabled
        self.streakRemindersEnabled = streakRemindersEnabled
        // Default to 9 AM
        self.preferredReminderTime = preferredReminderTime ?? Self.defaultReminderTime()
        self.quietHoursEnabled = quietHoursEnabled
    }

    // MARK: Internal

    /// Whether to send reminders when practice is due
    var practiceRemindersEnabled: Bool

    /// Whether to send reminders to maintain streak
    var streakRemindersEnabled: Bool

    /// Preferred time of day for reminder notifications
    var preferredReminderTime: Date

    /// Whether to suppress notifications during quiet hours (10 PM - 8 AM)
    var quietHoursEnabled: Bool

    // MARK: Private

    /// Default reminder time: 9:00 AM today
    private static func defaultReminderTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
