import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Your Callsign", text: $settingsStore.settings.userCallsign)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            Section("Audio") {
                VStack(alignment: .leading) {
                    Text("Tone Frequency: \(Int(settingsStore.settings.toneFrequency)) Hz")
                    Slider(
                        value: $settingsStore.settings.toneFrequency,
                        in: 400...800,
                        step: 25
                    )
                }

                VStack(alignment: .leading) {
                    Text("Effective Speed: \(settingsStore.settings.effectiveSpeed) WPM")
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.settings.effectiveSpeed) },
                            set: { settingsStore.settings.effectiveSpeed = Int($0) }
                        ),
                        in: 10...18,
                        step: 1
                    )
                }
            }

            Section("Notifications") {
                if notificationManager.authorizationStatus == .notDetermined {
                    Button("Enable Notifications") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                } else if notificationManager.authorizationStatus == .denied {
                    Text("Notifications are disabled. Enable them in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Toggle(
                        "Practice Reminders",
                        isOn: $settingsStore.settings.notificationSettings.practiceRemindersEnabled
                    )

                    Toggle(
                        "Streak Reminders",
                        isOn: $settingsStore.settings.notificationSettings.streakRemindersEnabled
                    )

                    DatePicker(
                        "Preferred Time",
                        selection: $settingsStore.settings.notificationSettings.preferredReminderTime,
                        displayedComponents: .hourAndMinute
                    )

                    Toggle(
                        "Quiet Hours (10 PM - 8 AM)",
                        isOn: $settingsStore.settings.notificationSettings.quietHoursEnabled
                    )
                }
            }

            Section("Progress") {
                HStack {
                    Text("Current Level")
                    Spacer()
                    Text("\(progressStore.progress.currentLevel) of 26")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Overall Accuracy")
                    Spacer()
                    Text("\(progressStore.overallAccuracyPercentage)%")
                        .foregroundColor(.secondary)
                }

                if progressStore.progress.schedule.currentStreak > 0 {
                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("\(progressStore.progress.schedule.currentStreak) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Longest Streak")
                        Spacer()
                        Text("\(progressStore.progress.schedule.longestStreak) days")
                            .foregroundColor(.secondary)
                    }
                }

                Button("Reset All Progress", role: .destructive) {
                    showResetConfirmation = true
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset Progress?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                progressStore.resetProgress()
            }
        } message: {
            Text("This will delete all your progress and start over from Level 1. This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsStore())
            .environmentObject(ProgressStore())
            .environmentObject(NotificationManager())
    }
}
