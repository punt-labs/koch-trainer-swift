import Foundation

/// User preferences for notification behavior.
struct NotificationSettings: Equatable {

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
        self._preferredReminderHour = max(0, min(23, preferredReminderHour))
        self._preferredReminderMinute = max(0, min(59, preferredReminderMinute))
        self.quietHoursEnabled = quietHoursEnabled
    }

    // MARK: Internal

    /// Whether to send reminders when practice is due
    var practiceRemindersEnabled: Bool

    /// Whether to send reminders to maintain streak
    var streakRemindersEnabled: Bool

    /// Preferred hour of day for reminder notifications (0-23)
    var preferredReminderHour: Int {
        get { _preferredReminderHour }
        set { _preferredReminderHour = max(0, min(23, newValue)) }
    }

    /// Preferred minute for reminder notifications (0-59)
    var preferredReminderMinute: Int {
        get { _preferredReminderMinute }
        set { _preferredReminderMinute = max(0, min(59, newValue)) }
    }

    /// Whether to suppress notifications during quiet hours (10 PM - 8 AM)
    var quietHoursEnabled: Bool

    // MARK: Private

    private var _preferredReminderHour: Int
    private var _preferredReminderMinute: Int
}

// MARK: - Codable

extension NotificationSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case practiceRemindersEnabled
        case streakRemindersEnabled
        case preferredReminderHour
        case preferredReminderMinute
        case quietHoursEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        practiceRemindersEnabled = try container.decode(Bool.self, forKey: .practiceRemindersEnabled)
        streakRemindersEnabled = try container.decode(Bool.self, forKey: .streakRemindersEnabled)
        let hour = try container.decode(Int.self, forKey: .preferredReminderHour)
        _preferredReminderHour = max(0, min(23, hour))
        let minute = try container.decode(Int.self, forKey: .preferredReminderMinute)
        _preferredReminderMinute = max(0, min(59, minute))
        quietHoursEnabled = try container.decode(Bool.self, forKey: .quietHoursEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(practiceRemindersEnabled, forKey: .practiceRemindersEnabled)
        try container.encode(streakRemindersEnabled, forKey: .streakRemindersEnabled)
        try container.encode(_preferredReminderHour, forKey: .preferredReminderHour)
        try container.encode(_preferredReminderMinute, forKey: .preferredReminderMinute)
        try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
    }
}
