import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    // MARK: Internal

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
                        in: 400 ... 800,
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
                        in: 10 ... 18,
                        step: 1
                    )
                }
            }

            Section("Band Conditions") {
                Toggle("Enable Band Conditions", isOn: $settingsStore.settings.bandConditionsEnabled)

                if settingsStore.settings.bandConditionsEnabled {
                    VStack(alignment: .leading) {
                        Text("Noise Level (QRN): \(Int(settingsStore.settings.noiseLevel * 100))%")
                        Slider(value: $settingsStore.settings.noiseLevel, in: 0 ... 1, step: 0.1)
                    }

                    Toggle("Signal Fading (QSB)", isOn: $settingsStore.settings.fadingEnabled)

                    if settingsStore.settings.fadingEnabled {
                        VStack(alignment: .leading) {
                            Text("Fading Depth: \(Int(settingsStore.settings.fadingDepth * 100))%")
                            Slider(value: $settingsStore.settings.fadingDepth, in: 0 ... 1, step: 0.1)
                        }

                        VStack(alignment: .leading) {
                            let rateText = String(format: "%.2f", settingsStore.settings.fadingRate)
                            Text("Fading Rate: \(rateText) Hz")
                            Slider(value: $settingsStore.settings.fadingRate, in: 0.02 ... 0.3, step: 0.02)
                        }
                    }

                    Toggle("Interference (QRM)", isOn: $settingsStore.settings.interferenceEnabled)

                    if settingsStore.settings.interferenceEnabled {
                        VStack(alignment: .leading) {
                            Text("Interference Level: \(Int(settingsStore.settings.interferenceLevel * 100))%")
                            Slider(value: $settingsStore.settings.interferenceLevel, in: 0 ... 1, step: 0.1)
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
                        selection: preferredTimeBinding,
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

                NavigationLink(destination: SessionHistoryView()) {
                    HStack {
                        Text("Session History")
                        Spacer()
                        Text("\(progressStore.progress.sessionHistory.count) sessions")
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
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: WhatsNewView()) {
                    Label("What's New", systemImage: "sparkles")
                }

                NavigationLink(destination: LicenseView()) {
                    Label("License", systemImage: "doc.text")
                }

                NavigationLink(destination: AcknowledgmentsView()) {
                    Label("Acknowledgments", systemImage: "heart")
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift/blob/main/PRIVACY.md") {
                    Link(destination: url) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift") {
                    Link(destination: url) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift/issues") {
                    Link(destination: url) {
                        Label("Support & Feedback", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                    }
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

    // MARK: Private

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showResetConfirmation = false
    @State private var isPreviewingBandConditions = false
    @StateObject private var previewAudioEngine = MorseAudioEngine()

    /// Binding that converts between hour/minute Ints and Date for the DatePicker
    private var preferredTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = settingsStore.settings.notificationSettings.preferredReminderHour
                components.minute = settingsStore.settings.notificationSettings.preferredReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                settingsStore.settings.notificationSettings.preferredReminderHour =
                    Calendar.current.component(.hour, from: newDate)
                settingsStore.settings.notificationSettings.preferredReminderMinute =
                    Calendar.current.component(.minute, from: newDate)
            }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        let hasVersion = version?.isEmpty == false
        let hasBuild = build?.isEmpty == false

        switch (hasVersion, hasBuild) {
        case (true, true):
            return "\(version ?? "") (\(build ?? ""))"
        case (true, false):
            return version ?? ""
        case (false, true):
            return "Build \(build ?? "")"
        case (false, false):
            return "Unknown version"
        }
    }

    // MARK: - Band Conditions Helpers

    private func previewBandConditions() {
        isPreviewingBandConditions = true
        previewAudioEngine.setFrequency(settingsStore.settings.toneFrequency)
        previewAudioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        previewAudioEngine.configureBandConditions(from: settingsStore.settings)

        // Use continuous audio session for realistic preview
        previewAudioEngine.startSession()

        Task {
            // Play "CQ CQ" to demonstrate band conditions with continuous noise
            await previewAudioEngine.playGroup("CQ CQ")
            previewAudioEngine.endSession()
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

// MARK: - BandConditionPreset

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
