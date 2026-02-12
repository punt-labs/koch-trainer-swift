import Foundation
import os
import UserNotifications

// MARK: - NotificationSettingsProtocol

/// Protocol for abstracting UNNotificationSettings for testability.
protocol NotificationSettingsProtocol: Sendable {
    var authorizationStatus: UNAuthorizationStatus { get }
}

// MARK: - UNNotificationSettings + NotificationSettingsProtocol

/// Make UNNotificationSettings conform to our protocol.
extension UNNotificationSettings: NotificationSettingsProtocol {}

// MARK: - NotificationCenterProtocol

/// Protocol for abstracting UNUserNotificationCenter for testability.
protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationSettings() async -> NotificationSettingsProtocol
    func add(_ request: UNNotificationRequest, withCompletionHandler: (@Sendable (Error?) -> Void)?)
    func removeAllPendingNotificationRequests()
}

// MARK: - UNUserNotificationCenter + NotificationCenterProtocol

/// Default implementation using the real UNUserNotificationCenter.
extension UNUserNotificationCenter: NotificationCenterProtocol {
    func notificationSettings() async -> NotificationSettingsProtocol {
        await withCheckedContinuation { continuation in
            self.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}

// MARK: - NotificationManager

/// Manages local notifications for practice reminders and streak alerts.
@MainActor
final class NotificationManager: ObservableObject {

    // MARK: Lifecycle

    init(
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        defaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.defaults = defaults

        // Initialize with cached status to prevent view re-renders during initial async check
        let cachedRawValue = defaults.integer(forKey: cachedStatusKey)
        authorizationStatus = UNAuthorizationStatus(rawValue: cachedRawValue) ?? .notDetermined

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
            logger.error("Notification authorization error: \(error.localizedDescription)")
            return false
        }
    }

    /// Refresh the current authorization status.
    /// Only updates the published property if the status actually changed,
    /// preventing unnecessary view re-renders that can interrupt VoiceOver.
    func refreshAuthorizationStatus() async {
        let settingsProtocol = await notificationCenter.notificationSettings()
        let newStatus = settingsProtocol.authorizationStatus

        // Cache for future inits to prevent re-renders
        defaults.set(newStatus.rawValue, forKey: cachedStatusKey)

        // Only publish if changed to avoid view re-renders during VoiceOver
        if authorizationStatus != newStatus {
            authorizationStatus = newStatus
        }
    }

    /// Schedule all notifications based on current schedule and settings.
    func scheduleNotifications(for schedule: PracticeSchedule, settings: NotificationSettings) {
        cancelAllNotifications()
        guard authorizationStatus == .authorized else { return }

        var scheduledTimes: [Date] = []
        let practiceCount = scheduledTimes.count
        schedulePracticeReminders(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        let hasPracticeReminder = scheduledTimes.count > practiceCount
        scheduleStreakReminderIfNeeded(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        scheduleLevelReviews(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        if !hasPracticeReminder {
            scheduleWelcomeBackIfNeeded(schedule: schedule, settings: settings, scheduledTimes: &scheduledTimes)
        }
    }

    /// Cancel all scheduled notifications.
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: Private

    /// Notification identifiers
    private enum NotificationID {
        static let practiceReceive = "practice.receive"
        static let practiceSend = "practice.send"
        static let streakReminder = "streak.reminder"
        static let welcomeBack = "welcome.back"

        static func levelReview(_ level: Int) -> String {
            "level.review.\(level)"
        }
    }

    // Anti-nag constants
    private static let maxNotificationsPerDay = 2
    private static let minimumGapHours = 4
    private static let quietHoursStart = 22 // 10 PM
    private static let quietHoursEnd = 8 // 8 AM

    private let notificationCenter: NotificationCenterProtocol
    private let defaults: UserDefaults
    private let cachedStatusKey = "notificationAuthorizationStatus"
    private let logger = Logger(subsystem: "com.kochtrainer", category: "NotificationManager")

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
                    title: String(localized: "notification.practiceDue.title"),
                    body: String(localized: "notification.practiceDue.body.receive")
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
                    title: String(localized: "notification.practiceDue.title"),
                    body: String(localized: "notification.practiceDue.body.send")
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
        guard settings.streakRemindersEnabled, schedule.currentStreak >= 7,
              !StreakCalculator.hasPracticedToday(lastStreakDate: schedule.lastStreakDate) else { return }

        // Try today at 8 PM, fall back to tomorrow if today's time has passed
        var targetDate = todayAt(hour: 20)
        if targetDate <= Date() {
            targetDate = tomorrowAt(hour: 20)
        }
        let adjusted = adjustForQuietHours(targetDate, settings: settings)
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

        let adjusted = adjustForQuietHours(
            tomorrowAt(hour: settings.preferredReminderHour, minute: settings.preferredReminderMinute),
            settings: settings
        )
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
        content.title = String(localized: "notification.streakReminder.title")
        content.body = String(localized: "notification.streakReminder.body \(streak)")
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
        content.title = String(localized: "notification.levelReview.title")
        content.body = String(localized: "notification.levelReview.body \(level)")
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
        content.title = String(localized: "notification.welcomeBack.title")
        content.body = String(localized: "notification.welcomeBack.body")
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

    private func todayAt(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private func tomorrowAt(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return Date() }
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
