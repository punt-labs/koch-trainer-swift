import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    // MARK: Internal

    var body: some View {
        AccessibleForm {
            // MARK: - Profile Section

            AccessibleSection("Profile") {
                AccessibleRow(showDivider: false) {
                    TextField("Your Callsign", text: $settings.userCallsign)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }

            // MARK: - Audio Section

            AccessibleSection("Audio") {
                AccessibleRow {
                    LabeledContent("Tone Frequency") {
                        Text("\(Int(settings.toneFrequency)) Hz")
                            .foregroundColor(.secondary)
                    }
                }
                AccessibleRow {
                    Slider(
                        value: $settings.toneFrequency,
                        in: 400 ... 800,
                        step: 25
                    ) {
                        Text("Tone Frequency")
                    }
                    .accessibilityValue("\(Int(settings.toneFrequency)) Hertz")
                }
                AccessibleRow {
                    LabeledContent("Effective Speed") {
                        Text("\(settings.effectiveSpeed) WPM")
                            .foregroundColor(.secondary)
                    }
                }
                AccessibleRow(showDivider: false) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.effectiveSpeed) },
                            set: { settings.effectiveSpeed = Int($0) }
                        ),
                        in: 10 ... 18,
                        step: 1
                    ) {
                        Text("Effective Speed")
                    }
                    .accessibilityValue("\(settings.effectiveSpeed) words per minute")
                }
            }

            // MARK: - Band Conditions Section

            AccessibleSection("Band Conditions") {
                AccessibleRow(showDivider: settings.bandConditionsEnabled) {
                    Toggle("Enable Band Conditions", isOn: $settings.bandConditionsEnabled)
                }

                if settings.bandConditionsEnabled {
                    AccessibleRow {
                        VStack(alignment: .leading) {
                            Text("Noise Level (QRN): \(Int(settings.noiseLevel * 100))%")
                            Slider(value: $settings.noiseLevel, in: 0 ... 1, step: 0.1)
                        }
                    }

                    AccessibleRow(showDivider: settings.fadingEnabled) {
                        Toggle("Signal Fading (QSB)", isOn: $settings.fadingEnabled)
                    }

                    if settings.fadingEnabled {
                        AccessibleRow {
                            VStack(alignment: .leading) {
                                Text("Fading Depth: \(Int(settings.fadingDepth * 100))%")
                                Slider(value: $settings.fadingDepth, in: 0 ... 1, step: 0.1)
                            }
                        }

                        AccessibleRow {
                            VStack(alignment: .leading) {
                                let rateText = String(format: "%.2f", settings.fadingRate)
                                Text("Fading Rate: \(rateText) Hz")
                                Slider(value: $settings.fadingRate, in: 0.02 ... 0.3, step: 0.02)
                            }
                        }
                    }

                    AccessibleRow(showDivider: settings.interferenceEnabled) {
                        Toggle("Interference (QRM)", isOn: $settings.interferenceEnabled)
                    }

                    if settings.interferenceEnabled {
                        AccessibleRow {
                            VStack(alignment: .leading) {
                                Text("Interference Level: \(Int(settings.interferenceLevel * 100))%")
                                Slider(value: $settings.interferenceLevel, in: 0 ... 1, step: 0.1)
                            }
                        }
                    }

                    AccessibleRow {
                        Button(action: previewBandConditions) {
                            HStack {
                                Image(systemName: isPreviewingBandConditions ? "speaker.wave.2.fill" : "speaker.wave.2")
                                Text(isPreviewingBandConditions ? "Playing..." : "Preview Sound")
                            }
                        }
                        .disabled(isPreviewingBandConditions)
                    }

                    AccessibleRow(showDivider: false) {
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
            }

            // MARK: - Notifications Section

            AccessibleSection("Notifications") {
                if notificationManager.authorizationStatus == .notDetermined {
                    AccessibleRow(showDivider: false) {
                        Button("Enable Notifications") {
                            Task {
                                await notificationManager.requestAuthorization()
                            }
                        }
                    }
                } else if notificationManager.authorizationStatus == .denied {
                    AccessibleRow(showDivider: false) {
                        Text("Notifications are disabled. Enable them in Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    AccessibleRow {
                        Toggle(
                            "Practice Reminders",
                            isOn: $settings.notificationSettings.practiceRemindersEnabled
                        )
                    }
                    AccessibleRow {
                        Toggle(
                            "Streak Reminders",
                            isOn: $settings.notificationSettings.streakRemindersEnabled
                        )
                    }
                    AccessibleRow {
                        DatePicker(
                            "Preferred Time",
                            selection: preferredTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    AccessibleRow(showDivider: false) {
                        Toggle(
                            "Quiet Hours (10 PM - 8 AM)",
                            isOn: $settings.notificationSettings.quietHoursEnabled
                        )
                    }
                }
            }

            // MARK: - Progress Section

            AccessibleSection("Progress") {
                AccessibleRow {
                    HStack {
                        Text("Current Level")
                        Spacer()
                        Text("\(progressStore.progress.currentLevel) of 26")
                            .foregroundColor(.secondary)
                    }
                }
                AccessibleRow {
                    HStack {
                        Text("Overall Accuracy")
                        Spacer()
                        Text("\(progressStore.overallAccuracyPercentage)%")
                            .foregroundColor(.secondary)
                    }
                }

                if progressStore.progress.schedule.currentStreak > 0 {
                    AccessibleRow {
                        HStack {
                            Text("Current Streak")
                            Spacer()
                            Text("\(progressStore.progress.schedule.currentStreak) days")
                                .foregroundColor(.secondary)
                        }
                    }
                    AccessibleRow {
                        HStack {
                            Text("Longest Streak")
                            Spacer()
                            Text("\(progressStore.progress.schedule.longestStreak) days")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                AccessibleRow {
                    NavigationLink(destination: SessionHistoryView()) {
                        HStack {
                            Text("Session History")
                            Spacer()
                            Text("\(progressStore.progress.sessionHistory.count) sessions")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(AccessibilityID.Settings.sessionHistoryLink)
                }

                AccessibleRow(showDivider: false) {
                    Button("Reset All Progress", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .accessibilityIdentifier(AccessibilityID.Settings.resetProgressButton)
                }
            }

            // MARK: - About Section

            AccessibleSection("About") {
                AccessibleRow {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
                AccessibleRow {
                    NavigationLink(destination: WhatsNewView()) {
                        HStack {
                            Label("What's New", systemImage: "sparkles")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Settings.whatsNewLink)
                }
                AccessibleRow {
                    NavigationLink(destination: LicenseView()) {
                        HStack {
                            Label("License", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                AccessibleRow {
                    NavigationLink(destination: AcknowledgmentsView()) {
                        HStack {
                            Label("Acknowledgments", systemImage: "heart")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Settings.acknowledgementsLink)
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift/blob/main/PRIVACY.md") {
                    AccessibleRow {
                        Link(destination: url) {
                            HStack {
                                Label("Privacy Policy", systemImage: "hand.raised")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift") {
                    AccessibleRow {
                        Link(destination: url) {
                            HStack {
                                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let url = URL(string: "https://github.com/punt-labs/koch-trainer-swift/issues") {
                    AccessibleRow(showDivider: false) {
                        Link(destination: url) {
                            HStack {
                                Label("Support & Feedback", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier(AccessibilityID.Settings.view)
        .alert("Reset Progress?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                progressStore.resetProgress()
            }
        } message: {
            Text("This will delete all your progress and start over from Level 1. This cannot be undone.")
        }
        .onAppear {
            // Copy settings to local state to isolate from @EnvironmentObject observation
            settings = settingsStore.settings
        }
        .onChange(of: settings) { _, newSettings in
            // Sync changes back to store
            settingsStore.settings = newSettings
        }
    }

    // MARK: Private

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var notificationManager: NotificationManager

    /// Local copy of settings to isolate view from @EnvironmentObject observation during VoiceOver.
    /// Changes sync back to store immediately via onChange.
    @State private var settings = AppSettings()

    @State private var showResetConfirmation = false
    @State private var isPreviewingBandConditions = false
    @StateObject private var previewAudioEngineWrapper = ObservableAudioEngine()

    /// Binding that converts between hour/minute Ints and Date for the DatePicker
    private var preferredTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = settings.notificationSettings.preferredReminderHour
                components.minute = settings.notificationSettings.preferredReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                settings.notificationSettings.preferredReminderHour =
                    Calendar.current.component(.hour, from: newDate)
                settings.notificationSettings.preferredReminderMinute =
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
        previewAudioEngineWrapper.engine.setFrequency(settings.toneFrequency)
        previewAudioEngineWrapper.engine.setEffectiveSpeed(settings.effectiveSpeed)
        previewAudioEngineWrapper.engine.configureBandConditions(from: settings)

        // Use continuous audio session for realistic preview
        previewAudioEngineWrapper.engine.startSession()

        Task {
            // Play "CQ CQ" to demonstrate band conditions with continuous noise
            await previewAudioEngineWrapper.engine.playGroup("CQ CQ")
            previewAudioEngineWrapper.engine.endSession()
            isPreviewingBandConditions = false
        }
    }

    private func applyPreset(_ preset: BandConditionPreset) {
        switch preset {
        case .goodConditions:
            settings.noiseLevel = 0.1
            settings.fadingEnabled = true
            settings.fadingDepth = 0.2
            settings.fadingRate = 0.05
            settings.interferenceEnabled = false
        case .contestPileup:
            settings.noiseLevel = 0.3
            settings.fadingEnabled = true
            settings.fadingDepth = 0.4
            settings.fadingRate = 0.1
            settings.interferenceEnabled = true
            settings.interferenceLevel = 0.4
        case .difficult:
            settings.noiseLevel = 0.5
            settings.fadingEnabled = true
            settings.fadingDepth = 0.7
            settings.fadingRate = 0.15
            settings.interferenceEnabled = true
            settings.interferenceLevel = 0.3
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
