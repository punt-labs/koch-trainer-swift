import Foundation

/// User preferences for notification behavior.
struct NotificationSettings: Codable, Equatable {

    // MARK: Lifecycle

    init(
        practiceRemindersEnabled: Bool = true,
        streakRemindersEnabled: Bool = true,
        preferredReminderHour: Int = 9,
        preferredReminderMinute: Int = 0,
        quietHoursEnabled: Bool = true
    ) {
        self.practiceRemindersEnabled = practiceRemindersEnabled
        self.streakRemindersEnabled = streakRemindersEnabled
        self.preferredReminderHour = preferredReminderHour
        self.preferredReminderMinute = preferredReminderMinute
        self.quietHoursEnabled = quietHoursEnabled
    }

    // MARK: Internal

    /// Whether to send reminders when practice is due
    var practiceRemindersEnabled: Bool

    /// Whether to send reminders to maintain streak
    var streakRemindersEnabled: Bool

    /// Preferred hour of day for reminder notifications (0-23)
    var preferredReminderHour: Int

    /// Preferred minute for reminder notifications (0-59)
    var preferredReminderMinute: Int

    /// Whether to suppress notifications during quiet hours (10 PM - 8 AM)
    var quietHoursEnabled: Bool
}
