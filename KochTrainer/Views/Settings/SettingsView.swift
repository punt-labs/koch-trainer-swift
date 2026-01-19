import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showResetConfirmation = false
    @State private var isPreviewingBandConditions = false
    @StateObject private var previewAudioEngine = MorseAudioEngine()

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

            Section("Band Conditions") {
                Toggle("Enable Band Conditions", isOn: $settingsStore.settings.bandConditionsEnabled)

                if settingsStore.settings.bandConditionsEnabled {
                    VStack(alignment: .leading) {
                        Text("Noise Level (QRN): \(Int(settingsStore.settings.noiseLevel * 100))%")
                        Slider(value: $settingsStore.settings.noiseLevel, in: 0...1, step: 0.1)
                    }

                    Toggle("Signal Fading (QSB)", isOn: $settingsStore.settings.fadingEnabled)

                    if settingsStore.settings.fadingEnabled {
                        VStack(alignment: .leading) {
                            Text("Fading Depth: \(Int(settingsStore.settings.fadingDepth * 100))%")
                            Slider(value: $settingsStore.settings.fadingDepth, in: 0...1, step: 0.1)
                        }

                        VStack(alignment: .leading) {
                            let rateText = String(format: "%.2f", settingsStore.settings.fadingRate)
                            Text("Fading Rate: \(rateText) Hz")
                            Slider(value: $settingsStore.settings.fadingRate, in: 0.02...0.3, step: 0.02)
                        }
                    }

                    Toggle("Interference (QRM)", isOn: $settingsStore.settings.interferenceEnabled)

                    if settingsStore.settings.interferenceEnabled {
                        VStack(alignment: .leading) {
                            Text("Interference Level: \(Int(settingsStore.settings.interferenceLevel * 100))%")
                            Slider(value: $settingsStore.settings.interferenceLevel, in: 0...1, step: 0.1)
                        }
                    }

                    Button(action: previewBandConditions) {
                        HStack {
                            Image(systemName: isPreviewingBandConditions ? "speaker.wave.2.fill" : "speaker.wave.2")
                            Text(isPreviewingBandConditions ? "Playing..." : "Preview Sound")
                        }
                    }
                    .disabled(isPreviewingBandConditions)

                    // Presets
                    Menu("Apply Preset") {
                        Button("Good Conditions") {
                            applyPreset(.goodConditions)
                        }
                        Button("Contest Pileup") {
                            applyPreset(.contestPileup)
                        }
                        Button("Difficult") {
                            applyPreset(.difficult)
                        }
                    }
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

    // MARK: - Band Conditions Helpers

    private func previewBandConditions() {
        isPreviewingBandConditions = true
        previewAudioEngine.setFrequency(settingsStore.settings.toneFrequency)
        previewAudioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        previewAudioEngine.configureBandConditions(from: settingsStore.settings)
        previewAudioEngine.reset()

        Task {
            // Play "CQ" to demonstrate band conditions
            await previewAudioEngine.playGroup("CQ CQ")
            isPreviewingBandConditions = false
        }
    }

    private func applyPreset(_ preset: BandConditionPreset) {
        switch preset {
        case .goodConditions:
            settingsStore.settings.noiseLevel = 0.1
            settingsStore.settings.fadingEnabled = true
            settingsStore.settings.fadingDepth = 0.2
            settingsStore.settings.fadingRate = 0.05
            settingsStore.settings.interferenceEnabled = false
        case .contestPileup:
            settingsStore.settings.noiseLevel = 0.3
            settingsStore.settings.fadingEnabled = true
            settingsStore.settings.fadingDepth = 0.4
            settingsStore.settings.fadingRate = 0.1
            settingsStore.settings.interferenceEnabled = true
            settingsStore.settings.interferenceLevel = 0.4
        case .difficult:
            settingsStore.settings.noiseLevel = 0.5
            settingsStore.settings.fadingEnabled = true
            settingsStore.settings.fadingDepth = 0.7
            settingsStore.settings.fadingRate = 0.15
            settingsStore.settings.interferenceEnabled = true
            settingsStore.settings.interferenceLevel = 0.3
        }
    }
}

enum BandConditionPreset {
    case goodConditions
    case contestPileup
    case difficult
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsStore())
            .environmentObject(ProgressStore())
            .environmentObject(NotificationManager())
    }
}
