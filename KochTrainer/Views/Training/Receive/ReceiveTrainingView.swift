import SwiftUI

// MARK: - ReceiveTrainingView

struct ReceiveTrainingView: View {

    // MARK: Lifecycle

    init(customCharacters: [Character]? = nil) {
        self.customCharacters = customCharacters
    }

    // MARK: Internal

    /// Optional custom characters for practice mode
    let customCharacters: [Character]?

    var navigationTitle: String {
        switch viewModel.phase {
        case .introduction:
            return String(localized: "Learn Characters")
        case .training,
             .paused:
            return String(localized: "Receive Training")
        case .completed:
            return String(localized: "Complete!")
        }
    }

    var isTrainingActive: Bool {
        if case .training = viewModel.phase { return true }
        if case .paused = viewModel.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Hidden text field for keyboard capture (only active during training)
            if case .training = viewModel.phase {
                TextField("", text: $hiddenInput)
                    .focused($isKeyboardFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .onChange(of: hiddenInput) { _, newValue in
                        if let lastChar = newValue.last {
                            viewModel.handleKeyPress(lastChar)
                        }
                        hiddenInput = ""
                    }
            }

            // Main content based on phase
            switch viewModel.phase {
            case .introduction:
                CharacterIntroductionView(viewModel: viewModel, startButtonKey: "Start Receive Training")

            case .training:
                TrainingPhaseView(viewModel: viewModel)
                    .onAppear {
                        isKeyboardFocused = true
                    }
                    .onTapGesture {
                        isKeyboardFocused = true
                    }

            case .paused:
                PausedView(viewModel: viewModel)

            case let .completed(didAdvance, newCharacter):
                CompletedView(
                    viewModel: viewModel,
                    didAdvance: didAdvance,
                    newCharacter: newCharacter,
                    dismiss: dismiss
                )
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isTrainingActive)
        .onAppear {
            if let custom = customCharacters {
                viewModel.configure(
                    progressStore: progressStore,
                    settingsStore: settingsStore,
                    customCharacters: custom
                )
            } else {
                viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            }

            // Check for paused session and restore directly
            let sessionType: SessionType = customCharacters != nil ? .receiveCustom : .receive
            if let paused = progressStore.pausedSession(for: sessionType),
               !paused.isExpired,
               paused.currentLevel == progressStore.progress.receiveLevel,
               paused.customCharacters == customCharacters {
                // Restore directly to paused state - no dialog needed
                viewModel.restoreFromPausedSession(paused)

                // Check if restoration succeeded (phase changed to paused or intro)
                // Don't clear the paused session yet - wait until user resumes/ends
                // so if they navigate away it can be restored again
                if case .paused = viewModel.phase {
                    // Restoration succeeded - session will be cleared when user resumes/ends
                } else if case .introduction = viewModel.phase {
                    // Restoration succeeded but user was mid-intro
                } else {
                    // Restoration failed, clear invalid session and start fresh
                    progressStore.clearPausedSession(for: paused.sessionType)
                    viewModel.startSession()
                }
            } else {
                viewModel.startSession()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, case .training = viewModel.phase {
                viewModel.pause()
            }
        }
    }

    // MARK: Private

    @StateObject private var viewModel = ReceiveTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool
    @State private var hiddenInput: String = ""

}

// MARK: - TrainingPhaseView

struct TrainingPhaseView: View {

    // MARK: Internal

    @ObservedObject var viewModel: ReceiveTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress toward proficiency
            Text(viewModel.proficiencyProgress)
                .font(Typography.body)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.Training.proficiencyProgress)

            Spacer()

            // Main display area - fixed slots prevent layout shifts
            VStack(spacing: 0) {
                // Slot 1: Main symbol (fixed height) - character, "?", or speaker icon
                Group {
                    if let feedback = viewModel.lastFeedback {
                        Text(String(feedback.expectedCharacter))
                            .font(Typography.characterDisplay(size: characterSize))
                            .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)
                    } else if viewModel.isWaitingForResponse {
                        Text("?")
                            .font(Typography.characterDisplay(size: characterSize))
                            .foregroundColor(Theme.Colors.primary)
                    } else if viewModel.currentCharacter != nil {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.primary)
                    } else {
                        Text(" ")
                            .font(Typography.characterDisplay(size: characterSize))
                    }
                }
                .frame(height: 100)
                .accessibilityIdentifier(AccessibilityID.Training.characterDisplay)

                // Slot 2: Secondary text (fixed height)
                Group {
                    if let feedback = viewModel.lastFeedback {
                        ReceiveFeedbackMessageView(feedback: feedback)
                    } else if viewModel.isWaitingForResponse {
                        Text("Type the letter you heard")
                            .font(Typography.body)
                            .foregroundColor(.secondary)
                    } else if viewModel.currentCharacter != nil {
                        Text("Listen...")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Starting...")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 40)
                .accessibilityIdentifier(AccessibilityID.Training.feedbackMessage)

                // Slot 3: Progress bar (always present, opacity controlled)
                TimeoutProgressBar(deadline: viewModel.timerDeadline, duration: viewModel.timerDuration)
                    .frame(height: 8)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.md)
                    .opacity(viewModel.isWaitingForResponse ? 1 : 0)
                    .accessibilityIdentifier(AccessibilityID.Training.progressBar)
            }
            .frame(height: 200)

            Spacer()

            // Score display
            HStack {
                Text("Correct: \(viewModel.counter.correct)/\(viewModel.counter.attempts)")
                    .accessibilityLabel(
                        "\(viewModel.counter.correct) correct out of \(viewModel.counter.attempts) attempts"
                    )
                    .accessibilityIdentifier(AccessibilityID.Training.scoreDisplay)
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .accessibilityLabel("\(viewModel.accuracyPercentage) percent accuracy")
                    .accessibilityIdentifier(AccessibilityID.Training.accuracyDisplay)
            }
            .font(Typography.body)

            // Pause button only
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Training.pauseButton)
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Training.trainingView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var characterSize: CGFloat = 80

}

// MARK: - PausedView

struct PausedView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Paused")
                .font(Typography.largeTitle)
                .accessibilityIdentifier(AccessibilityID.Training.pausedTitle)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Score: \(viewModel.counter.correct)/\(viewModel.counter.attempts)")
                    .font(Typography.headline)
                    .accessibilityIdentifier(AccessibilityID.Training.pausedScore)
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Resume") {
                viewModel.resume()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Training.resumeButton)

            Button("End Session") {
                viewModel.endSession()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.Training.endSessionButton)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Training.pausedView)
    }
}

// MARK: - CompletedView

struct CompletedView: View {

    // MARK: Internal

    @ObservedObject var viewModel: ReceiveTrainingViewModel

    let didAdvance: Bool
    let newCharacter: Character?
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            if didAdvance {
                // Level up celebration
                VStack(spacing: Theme.Spacing.md) {
                    Text("Level Up!")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.success)
                        .accessibilityIdentifier(AccessibilityID.Training.levelUpTitle)

                    if let char = newCharacter {
                        Text("New character unlocked:")
                            .font(Typography.body)
                            .foregroundColor(.secondary)

                        Text(String(char))
                            .font(Typography.characterDisplay(size: newCharacterSize))
                            .foregroundColor(Theme.Colors.primary)
                            .accessibilityIdentifier(AccessibilityID.Training.newCharacterDisplay)

                        Text(MorseCode.pattern(for: char) ?? "")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .accessibilityLabel(
                                AccessibilityAnnouncer.spokenPattern(MorseCode.pattern(for: char) ?? "")
                            )
                    }
                }
            } else {
                // Session complete without advancement
                Text("Session Complete")
                    .font(Typography.largeTitle)
                    .accessibilityIdentifier(AccessibilityID.Training.sessionCompleteTitle)
            }

            Spacer()

            // Stats
            VStack(spacing: Theme.Spacing.sm) {
                Text("\(viewModel.counter.correct)/\(viewModel.counter.attempts) correct")
                    .font(Typography.headline)
                    .accessibilityIdentifier(AccessibilityID.Training.finalScore)

                Text("\(viewModel.accuracyPercentage)% accuracy")
                    .font(Typography.body)
                    .foregroundColor(viewModel.accuracyPercentage >= 90 ? Theme.Colors.success : .secondary)
                    .accessibilityIdentifier(AccessibilityID.Training.finalAccuracy)

                if !didAdvance, viewModel.accuracyPercentage < 90 {
                    Text("Need 90% to advance")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .padding(.top, Theme.Spacing.sm)
                }
            }

            Spacer()

            if didAdvance {
                Button("Continue to Next Level") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Training.continueButton)
            } else {
                Button("Try Again") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Training.tryAgainButton)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Training.doneButton)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Training.completedView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var newCharacterSize: CGFloat = 80

}

// MARK: - ReceiveFeedbackMessageView

/// Shows just the feedback message text (without the character).
/// Used in the fixed-slot layout where character is displayed separately.
struct ReceiveFeedbackMessageView: View {
    let feedback: ReceiveTrainingViewModel.Feedback

    var body: some View {
        if feedback.wasCorrect {
            Text("Correct!")
                .font(Typography.headline)
                .foregroundColor(Theme.Colors.success)
                .accessibilityIdentifier(AccessibilityID.Training.feedbackCorrect)
        } else if let pressed = feedback.userPressed {
            Text("You pressed: \(String(pressed))")
                .font(Typography.body)
                .foregroundColor(Theme.Colors.error)
                .accessibilityIdentifier(AccessibilityID.Training.feedbackIncorrect)
        } else {
            Text("Too slow!")
                .font(Typography.headline)
                .foregroundColor(Theme.Colors.error)
                .accessibilityIdentifier(AccessibilityID.Training.feedbackTimeout)
        }
    }
}

// MARK: - TimeoutProgressBar

/// Countdown progress bar driven by wall clock time.
/// Uses TimelineView(.animation) to compute progress each frame — no withAnimation coordination needed.
struct TimeoutProgressBar: View {

    // MARK: Internal

    let deadline: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.animation) { timeline in
            let remaining = max(0, deadline.timeIntervalSince(timeline.date))
            let progress = duration > 0 ? remaining / duration : 0

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor(for: progress))
                        .frame(width: geometry.size.width * max(0, min(1, progress)))
                }
            }
        }
    }

    // MARK: Private

    private func progressColor(for progress: Double) -> Color {
        if progress > 0.5 {
            return Theme.Colors.success
        } else if progress > 0.25 {
            return Theme.Colors.warning
        } else {
            return Theme.Colors.error
        }
    }
}

#Preview {
    NavigationStack {
        ReceiveTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
