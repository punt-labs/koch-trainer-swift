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
        self.preferredReminderHour = max(0, min(23, preferredReminderHour))
        self.preferredReminderMinute = max(0, min(59, preferredReminderMinute))
        self.quietHoursEnabled = quietHoursEnabled
    }

    // MARK: Internal

    /// Whether to send reminders when practice is due
    var practiceRemindersEnabled: Bool

    /// Whether to send reminders to maintain streak
    var streakRemindersEnabled: Bool

    /// Preferred hour of day for reminder notifications (0-23)
    var preferredReminderHour: Int {
        didSet {
            preferredReminderHour = max(0, min(23, preferredReminderHour))
        }
    }

    /// Preferred minute for reminder notifications (0-59)
    var preferredReminderMinute: Int {
        didSet {
            preferredReminderMinute = max(0, min(59, preferredReminderMinute))
        }
    }

    /// Whether to suppress notifications during quiet hours (10 PM - 8 AM)
    var quietHoursEnabled: Bool
}
