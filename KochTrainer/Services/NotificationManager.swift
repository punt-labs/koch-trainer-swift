import Foundation
import UserNotifications

// MARK: - NotificationCenterProtocol

/// Protocol for abstracting UNUserNotificationCenter for testability.
protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationSettings() async -> UNNotificationSettings
    func add(_ request: UNNotificationRequest, withCompletionHandler: (@Sendable (Error?) -> Void)?)
    func removeAllPendingNotificationRequests()
}

// MARK: - UNUserNotificationCenter + NotificationCenterProtocol

/// Default implementation using the real UNUserNotificationCenter.
extension UNUserNotificationCenter: NotificationCenterProtocol {}

// MARK: - NotificationManager

/// Manages local notifications for practice reminders and streak alerts.
@MainActor
final class NotificationManager: ObservableObject {

    // MARK: Lifecycle

    init(notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: Internal

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Request notification authorization from the user.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// Refresh the current authorization status.
    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Schedule all notifications based on current schedule and settings.
    func scheduleNotifications(for schedule: PracticeSchedule, settings: NotificationSettings) {
        cancelAllNotifications()
        guard authorizationStatus == .authorized else { return }

        var scheduledTimes: [Date] = []
        schedulePracticeReminders(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        scheduleStreakReminderIfNeeded(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        scheduleLevelReviews(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        scheduleWelcomeBackIfNeeded(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
    }

    /// Cancel all scheduled notifications.
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: Private

    // Notification identifiers
    private enum NotificationID {
        static let practiceReceive = "practice.receive"
        static let practiceSend = "practice.send"
        static let streakReminder = "streak.reminder"
        static let welcomeBack = "welcome.back"

        static func levelReview(_ level: Int) -> String { "level.review.\(level)" }
    }

    // Anti-nag constants
    private static let maxNotificationsPerDay = 2
    private static let minimumGapHours = 4
    private static let quietHoursStart = 22 // 10 PM
    private static let quietHoursEnd = 8 // 8 AM

    private let notificationCenter: NotificationCenterProtocol

    private func schedulePracticeReminders(
        schedule: PracticeSchedule,
        settings: NotificationSettings,
        scheduledTimes: inout [Date]
    ) {
        guard settings.practiceRemindersEnabled else { return }

        if let receiveDate = schedule.receiveNextDate {
            let adjusted = adjustForQuietHours(receiveDate, settings: settings)
            if shouldSchedule(at: adjusted, existingTimes: scheduledTimes, settings: settings) {
                schedulePracticeNotification(
                    id: NotificationID.practiceReceive,
                    date: adjusted,
                    title: "Time to Practice",
                    body: "Your receive training session is ready."
                )
                scheduledTimes.append(adjusted)
            }
        }

        if let sendDate = schedule.sendNextDate {
            let adjusted = adjustForQuietHours(sendDate, settings: settings)
            if shouldSchedule(at: adjusted, existingTimes: scheduledTimes, settings: settings) {
                schedulePracticeNotification(
                    id: NotificationID.practiceSend,
                    date: adjusted,
                    title: "Time to Practice",
                    body: "Your send training session is ready."
                )
                scheduledTimes.append(adjusted)
            }
        }
    }

    private func scheduleStreakReminderIfNeeded(
        schedule: PracticeSchedule,
        settings: NotificationSettings,
        scheduledTimes: inout [Date]
    ) {
        guard settings.streakRemindersEnabled, schedule.currentStreak >= 3,
              !StreakCalculator.hasPracticedToday(lastStreakDate: schedule.lastStreakDate) else { return }

        let adjusted = adjustForQuietHours(todayAt(hour: 20), settings: settings)
        if shouldSchedule(at: adjusted, existingTimes: scheduledTimes, settings: settings) {
            scheduleStreakReminder(date: adjusted, streak: schedule.currentStreak)
            scheduledTimes.append(adjusted)
        }
    }

    private func scheduleLevelReviews(
        schedule: PracticeSchedule,
        settings: NotificationSettings,
        scheduledTimes: inout [Date]
    ) {
        guard settings.practiceRemindersEnabled else { return }

        for (level, reviewDate) in schedule.levelReviewDates {
            let adjusted = adjustForQuietHours(reviewDate, settings: settings)
            if shouldSchedule(at: adjusted, existingTimes: scheduledTimes, settings: settings) {
                scheduleLevelReviewNotification(level: level, date: adjusted)
                scheduledTimes.append(adjusted)
            }
        }
    }

    private func scheduleWelcomeBackIfNeeded(
        schedule: PracticeSchedule,
        settings: NotificationSettings,
        scheduledTimes: inout [Date]
    ) {
        guard settings.practiceRemindersEnabled, let lastDate = schedule.lastStreakDate else { return }

        let daysSinceLast = Int(Date().timeIntervalSince(lastDate) / 86400)
        guard daysSinceLast >= 7 else { return }

        let hour = Calendar.current.component(.hour, from: settings.preferredReminderTime)
        let adjusted = adjustForQuietHours(tomorrowAt(hour: hour), settings: settings)
        if shouldSchedule(at: adjusted, existingTimes: scheduledTimes, settings: settings) {
            scheduleWelcomeBackNotification(date: adjusted)
        }
    }

    // MARK: - Private Scheduling Methods

    private func schedulePracticeNotification(id: String, date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func scheduleStreakReminder(date: Date, streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Alive!"
        content.body = "You're on a \(streak)-day streak. Practice today to keep it going."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.streakReminder,
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func scheduleLevelReviewNotification(level: Int, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Review Time"
        content.body = "It's been a week since you reached level \(level). Time for a quick review!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.levelReview(level),
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func scheduleWelcomeBackNotification(date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "We Miss You!"
        content.body = "Ready to get back to learning Morse code? Your progress is waiting."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: NotificationID.welcomeBack, content: content, trigger: trigger)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    // MARK: - Anti-Nag Policy Helpers

    private func shouldSchedule(at date: Date, existingTimes: [Date], settings: NotificationSettings) -> Bool {
        // Check if date is in the past
        guard date > Date() else { return false }

        // Check maximum notifications per day
        let calendar = Calendar.current
        let sameDayCount = existingTimes.filter { calendar.isDate($0, inSameDayAs: date) }.count
        guard sameDayCount < Self.maxNotificationsPerDay else { return false }

        // Check minimum gap between notifications
        for existingTime in existingTimes {
            let gap = abs(date.timeIntervalSince(existingTime)) / 3600
            if gap < Double(Self.minimumGapHours) {
                return false
            }
        }

        return true
    }

    private func adjustForQuietHours(_ date: Date, settings: NotificationSettings) -> Date {
        guard settings.quietHoursEnabled else { return date }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Check if in quiet hours (10 PM - 8 AM)
        if hour >= Self.quietHoursStart || hour < Self.quietHoursEnd {
            // Move to 8 AM same day if before midnight, next day if after
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            if hour >= Self.quietHoursStart {
                // After 10 PM: move to 8 AM next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                    components = calendar.dateComponents([.year, .month, .day], from: nextDay)
                }
            }
            components.hour = Self.quietHoursEnd
            components.minute = 0
            return calendar.date(from: components) ?? date
        }

        return date
    }

    private func todayAt(hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }

    private func tomorrowAt(hour: Int) -> Date {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return Date() }
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }
}
