@testable import KochTrainer
import UserNotifications
import XCTest

// MARK: - MockNotificationCenter

/// Mock notification center for testing NotificationManager.
final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var grantAuthorization = true
    var addedRequests: [UNNotificationRequest] = []
    var removedAllPending = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return grantAuthorization
    }

    func notificationSettings() async -> UNNotificationSettings {
        // Create mock settings - we use a workaround since UNNotificationSettings can't be instantiated
        // The test will set authorizationStatus directly on the manager
        return await UNUserNotificationCenter.current().notificationSettings()
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func removeAllPendingNotificationRequests() {
        removedAllPending = true
        addedRequests.removeAll()
    }

    func reset() {
        addedRequests.removeAll()
        removedAllPending = false
    }
}

// MARK: - NotificationManagerTests

@MainActor
final class NotificationManagerTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        mockCenter = MockNotificationCenter()
        manager = NotificationManager(notificationCenter: mockCenter)
    }

    // MARK: - Cancel Tests

    func testCancelAllNotifications() {
        manager.cancelAllNotifications()

        XCTAssertTrue(mockCenter.removedAllPending)
    }

    // MARK: - Schedule Notifications Tests

    func testScheduleNotificationsWhenNotAuthorized() {
        // Manager starts with .notDetermined status
        let schedule = PracticeSchedule()
        let settings = NotificationSettings()

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should cancel existing but not add new ones
        XCTAssertTrue(mockCenter.removedAllPending)
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    // MARK: - shouldSchedule Tests (via scheduling behavior)

    func testPracticeRemindersScheduled() async throws {
        // Set up authorized status
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Set next dates in the future
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        schedule.receiveNextDate = tomorrow
        schedule.sendNextDate = Calendar.current.date(byAdding: .hour, value: 5, to: tomorrow)

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should have scheduled practice reminders
        XCTAssertEqual(mockCenter.addedRequests.count, 2)
    }

    func testPracticeRemindersNotScheduledWhenDisabled() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        schedule.receiveNextDate = tomorrow

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func testStreakReminderScheduledWhenCriteriaMet() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        schedule.currentStreak = 5
        // Last streak date was yesterday (hasn't practiced today)
        schedule.lastStreakDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        var settings = NotificationSettings()
        settings.streakRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should have streak reminder
        let streakRequests = mockCenter.addedRequests.filter { $0.identifier == "streak.reminder" }
        XCTAssertEqual(streakRequests.count, 1)
    }

    func testStreakReminderNotScheduledWhenStreakTooLow() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        schedule.currentStreak = 2 // Below threshold of 3
        schedule.lastStreakDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        var settings = NotificationSettings()
        settings.streakRemindersEnabled = true

        manager.scheduleNotifications(for: schedule, settings: settings)

        let streakRequests = mockCenter.addedRequests.filter { $0.identifier == "streak.reminder" }
        XCTAssertTrue(streakRequests.isEmpty)
    }

    func testStreakReminderNotScheduledWhenAlreadyPracticedToday() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        schedule.currentStreak = 5
        schedule.lastStreakDate = Date() // Practiced today

        var settings = NotificationSettings()
        settings.streakRemindersEnabled = true

        manager.scheduleNotifications(for: schedule, settings: settings)

        let streakRequests = mockCenter.addedRequests.filter { $0.identifier == "streak.reminder" }
        XCTAssertTrue(streakRequests.isEmpty)
    }

    func testLevelReviewScheduled() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        let reviewDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        schedule.levelReviewDates = [5: reviewDate]

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        let reviewRequests = mockCenter.addedRequests.filter { $0.identifier.starts(with: "level.review") }
        XCTAssertEqual(reviewRequests.count, 1)
    }

    func testWelcomeBackScheduledAfter7Days() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Last practice was 8 days ago
        schedule.lastStreakDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        let welcomeRequests = mockCenter.addedRequests.filter { $0.identifier == "welcome.back" }
        XCTAssertEqual(welcomeRequests.count, 1)
    }

    func testWelcomeBackNotScheduledWithin7Days() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Last practice was 5 days ago
        schedule.lastStreakDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true

        manager.scheduleNotifications(for: schedule, settings: settings)

        let welcomeRequests = mockCenter.addedRequests.filter { $0.identifier == "welcome.back" }
        XCTAssertTrue(welcomeRequests.isEmpty)
    }

    // MARK: - Anti-Nag Policy Tests

    func testMaxTwoNotificationsPerDay() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        // Schedule 3 notifications for the same day
        schedule.receiveNextDate = tomorrow
        schedule.sendNextDate = Calendar.current.date(byAdding: .hour, value: 1, to: tomorrow)
        let reviewDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 2, to: tomorrow))
        schedule.levelReviewDates = [1: reviewDate]

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should only schedule 2 (max per day)
        XCTAssertLessThanOrEqual(mockCenter.addedRequests.count, 2)
    }

    func testMinimumGapBetweenNotifications() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        // Schedule 2 notifications only 1 hour apart (less than 4 hour minimum)
        schedule.receiveNextDate = tomorrow
        schedule.sendNextDate = Calendar.current.date(byAdding: .hour, value: 1, to: tomorrow)

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should only schedule 1 due to minimum gap
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    func testNotificationsNotScheduledInPast() async {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Set dates in the past
        schedule.receiveNextDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true

        manager.scheduleNotifications(for: schedule, settings: settings)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    // MARK: - Quiet Hours Tests

    func testQuietHoursAdjustsLateNightToMorning() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Create a date at 11 PM tomorrow
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let day = try XCTUnwrap(components.day)
        components.day = day + 1
        components.hour = 23
        components.minute = 0
        let lateNight = try XCTUnwrap(Calendar.current.date(from: components))
        schedule.receiveNextDate = lateNight

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = true

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should schedule at 8 AM the next day
        if let request = mockCenter.addedRequests.first,
           let trigger = request.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 8)
        }
    }

    func testQuietHoursDisabledDoesNotAdjust() async throws {
        _ = await manager.requestAuthorization()
        await manager.refreshAuthorizationStatus()
        mockCenter.reset()

        var schedule = PracticeSchedule()
        // Create a date at 11 PM tomorrow
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let day = try XCTUnwrap(components.day)
        components.day = day + 1
        components.hour = 23
        components.minute = 0
        let lateNight = try XCTUnwrap(Calendar.current.date(from: components))
        schedule.receiveNextDate = lateNight

        var settings = NotificationSettings()
        settings.practiceRemindersEnabled = true
        settings.quietHoursEnabled = false

        manager.scheduleNotifications(for: schedule, settings: settings)

        // Should schedule at original time
        if let request = mockCenter.addedRequests.first,
           let trigger = request.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 23)
        }
    }

    // MARK: Private

    private var mockCenter = MockNotificationCenter()
    private lazy var manager = NotificationManager(notificationCenter: mockCenter)

}
