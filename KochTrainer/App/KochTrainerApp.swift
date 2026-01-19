import SwiftUI

@main
struct KochTrainerApp: App {

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(progressStore)
                .environmentObject(settingsStore)
                .environmentObject(notificationManager)
                .task {
                    await notificationManager.refreshAuthorizationStatus()
                }
                .onChange(of: progressStore.progress.schedule) { newSchedule in
                    rescheduleNotifications(schedule: newSchedule)
                }
                .onChange(of: settingsStore.settings.notificationSettings) { _ in
                    rescheduleNotifications(schedule: progressStore.progress.schedule)
                }
        }
    }

    // MARK: Private

    @StateObject private var progressStore = ProgressStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var notificationManager = NotificationManager()

    private func rescheduleNotifications(schedule: PracticeSchedule) {
        notificationManager.scheduleNotifications(
            for: schedule,
            settings: settingsStore.settings.notificationSettings
        )
    }
}
