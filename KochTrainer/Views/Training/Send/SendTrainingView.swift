import SwiftUI

// MARK: - SendTrainingView

struct SendTrainingView: View {

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
            return String(localized: "Send Training")
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
            // Main content based on phase
            switch viewModel.phase {
            case .introduction:
                CharacterIntroductionView(viewModel: viewModel, startButtonKey: "Start Send Training")

            case .training:
                SendTrainingPhaseView(viewModel: viewModel)

            case .paused:
                SendPausedView(viewModel: viewModel)

            case let .completed(didAdvance, newCharacter):
                SendCompletedView(
                    viewModel: viewModel,
                    didAdvance: didAdvance,
                    newCharacter: newCharacter,
                    dismiss: dismiss
                )
            }
        }
        .focusable()
        .focused($isKeyboardFocused)
        .onKeyPress { press in
            guard case .training = viewModel.phase,
                  let char = press.characters.first else {
                return .ignored
            }
            viewModel.handleKeyPress(char)
            return .handled
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
            let sessionType: SessionType = customCharacters != nil ? .sendCustom : .send
            if let paused = progressStore.pausedSession(for: sessionType),
               !paused.isExpired,
               paused.currentLevel == progressStore.progress.sendLevel,
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
            isKeyboardFocused = true
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

    @StateObject private var viewModel = SendTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool

}

// MARK: - SendTrainingPhaseView

struct SendTrainingPhaseView: View {

    // MARK: Internal

    @ObservedObject var viewModel: SendTrainingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Progress toward proficiency
                Text(viewModel.proficiencyProgress)
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Training.proficiencyProgress)

                // Main display area - fixed slots prevent layout shifts
                VStack(spacing: 0) {
                    // Slot 1: Character (fixed height)
                    Group {
                        if let feedback = viewModel.lastFeedback {
                            Text(String(feedback.expectedCharacter))
                                .font(Typography.characterDisplay(size: characterSize))
                                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)
                        } else {
                            Text(String(viewModel.targetCharacter))
                                .font(Typography.characterDisplay(size: characterSize))
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    .frame(height: 120)
                    .accessibilityIdentifier(AccessibilityID.Training.characterDisplay)

                    // Slot 2: Secondary content (fixed height)
                    Group {
                        if let feedback = viewModel.lastFeedback {
                            SendFeedbackMessageView(feedback: feedback)
                        } else {
                            Text(viewModel.currentPattern.isEmpty ? " " : viewModel.currentPattern)
                                .font(Typography.patternDisplay(size: patternSize))
                                .foregroundColor(.secondary)
                                .accessibilityLabel(
                                    viewModel.currentPattern.isEmpty
                                        ? ""
                                        : AccessibilityAnnouncer.spokenPattern(viewModel.currentPattern)
                                )
                                .accessibilityIdentifier(AccessibilityID.Send.patternDisplay)
                        }
                    }
                    .frame(height: 56)
                    .accessibilityIdentifier(AccessibilityID.Training.feedbackMessage)

                    // Slot 3: Progress bar (always present, opacity controlled)
                    // Animation controlled by ViewModel via withAnimation()
                    // .id() forces view recreation when timer resets, destroying in-flight animation
                    TimeoutProgressBar(progress: viewModel.inputProgress)
                        .id(viewModel.timerCycleId)
                        .frame(height: 8)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .opacity(viewModel.isWaitingForInput ? 1 : 0)
                        .accessibilityIdentifier(AccessibilityID.Training.progressBar)
                }
                .frame(height: 200)

                // Keyboard hint
                Text("Keyboard: . or F = dit, - or J = dah")
                    .font(Typography.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Send.keyboardHint)

                // Paddle area
                HStack(spacing: 2) {
                    // Dit button
                    Button {
                        viewModel.inputDit()
                    } label: {
                        Text("dit")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.primary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Short Morse element")
                    .accessibilityIdentifier(AccessibilityID.Send.ditButton)

                    // Dah button
                    Button {
                        viewModel.inputDah()
                    } label: {
                        Text("dah")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Long Morse element")
                    .accessibilityIdentifier(AccessibilityID.Send.dahButton)
                }
                .frame(height: 120)
                .cornerRadius(12)
                .clipped()

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

                // Pause button
                Button("Pause") {
                    viewModel.pause()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Training.pauseButton)
            }
            .padding(Theme.Spacing.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Training.trainingView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var characterSize: CGFloat = 100
    @ScaledMetric(relativeTo: .title) private var patternSize: CGFloat = 36

}

// MARK: - SendPausedView

struct SendPausedView: View {
    @ObservedObject var viewModel: SendTrainingViewModel

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

// MARK: - SendCompletedView

struct SendCompletedView: View {

    // MARK: Internal

    @ObservedObject var viewModel: SendTrainingViewModel

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

// MARK: - SendFeedbackMessageView

/// Shows just the feedback message text (without the character).
/// Used in the fixed-slot layout where character is displayed separately.
struct SendFeedbackMessageView: View {

    // MARK: Internal

    let feedback: SendTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
                    .accessibilityIdentifier(AccessibilityID.Training.feedbackCorrect)
            } else {
                Text("You sent: \(feedback.sentPattern)")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.error)
                    .accessibilityLabel(
                        "You sent: \(AccessibilityAnnouncer.spokenPattern(feedback.sentPattern))"
                    )
                    .accessibilityIdentifier(AccessibilityID.Training.feedbackIncorrect)

                if let decoded = feedback.decodedCharacter {
                    Text("(\(String(decoded))) — Should be: \(expectedPattern)")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(
                            "\(String(decoded)). Should be: \(AccessibilityAnnouncer.spokenPattern(expectedPattern))"
                        )
                } else {
                    Text("Should be: \(expectedPattern)")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(
                            "Should be: \(AccessibilityAnnouncer.spokenPattern(expectedPattern))"
                        )
                }
            }
        }
    }

    // MARK: Private

    private var expectedPattern: String {
        MorseCode.pattern(for: feedback.expectedCharacter) ?? ""
    }

}

#Preview {
    NavigationStack {
        SendTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
