import SwiftUI

// MARK: - Accessibility Helper

/// Spells out a word character by character for VoiceOver (e.g., "W1AW" → "W 1 A W")
private func spellOutWord(_ word: String) -> String {
    word.map { String($0) }.joined(separator: " ")
}

// MARK: - VocabularyTrainingView

struct VocabularyTrainingView: View {

    // MARK: Lifecycle

    init(vocabularySet: VocabularySet, sessionType: SessionType) {
        _viewModel = StateObject(wrappedValue: VocabularyTrainingViewModel(
            vocabularySet: vocabularySet,
            sessionType: sessionType
        ))
    }

    // MARK: Internal

    var navigationTitle: String {
        switch viewModel.phase {
        case .training,
             .paused:
            return viewModel.isReceiveMode ? "Vocabulary Receive" : "Vocabulary Send"
        case .completed:
            return "Complete!"
        }
    }

    var isTrainingActive: Bool {
        if case .training = viewModel.phase { return true }
        if case .paused = viewModel.phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Hidden text field for keyboard capture (receive mode only — needs software keyboard)
            if case .training = viewModel.phase, viewModel.isReceiveMode {
                TextField("", text: $textInput)
                    .focused($isKeyboardFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .onChange(of: textInput) { _, newValue in
                        if !viewModel.currentWord.isEmpty,
                           newValue.count >= viewModel.currentWord.count {
                            viewModel.submitAnswer(newValue)
                            textInput = ""
                        }
                    }
                    .onSubmit {
                        viewModel.submitAnswer(textInput)
                        textInput = ""
                    }
            }

            // Main content based on phase
            switch viewModel.phase {
            case .training:
                if viewModel.isReceiveMode {
                    ReceiveVocabTrainingPhaseView(viewModel: viewModel, textInput: $textInput)
                } else {
                    SendVocabTrainingPhaseView(viewModel: viewModel)
                }

            case .paused:
                VocabPausedView(viewModel: viewModel)

            case .completed:
                VocabCompletedView(viewModel: viewModel, dismiss: dismiss)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isTrainingActive)
        .focusable(!viewModel.isReceiveMode)
        .focused($isSendKeyboardFocused)
        .onKeyPress { press in
            guard !viewModel.isReceiveMode,
                  case .training = viewModel.phase,
                  let char = press.characters.first else {
                return .ignored
            }
            viewModel.handleKeyPress(char)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.view)
        .onAppear {
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)

            // Check for paused session and restore if it matches this vocabulary set
            if let paused = progressStore.pausedSession(for: viewModel.sessionType),
               !paused.isExpired,
               paused.isVocabularySession,
               paused.vocabularySetId == viewModel.vocabularySet.id {
                // Attempt to restore to paused state
                viewModel.restoreFromPausedSession(paused)

                // Check if restoration succeeded (phase changed to paused)
                if case .paused = viewModel.phase {
                    // Restoration succeeded - session will be cleared when user resumes/ends
                } else {
                    // Restoration failed, clear invalid session and start fresh
                    progressStore.clearPausedSession(for: paused.sessionType)
                    viewModel.startSession()
                }
            } else {
                viewModel.startSession()
            }
            if viewModel.isReceiveMode {
                isKeyboardFocused = true
            } else {
                isSendKeyboardFocused = true
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
        .onTapGesture {
            // Re-focus keyboard for receive mode (software keyboard)
            if viewModel.isReceiveMode {
                isKeyboardFocused = true
            }
        }
    }

    // MARK: Private

    @StateObject private var viewModel: VocabularyTrainingViewModel
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool
    @FocusState private var isSendKeyboardFocused: Bool
    @State private var textInput: String = ""

}

// MARK: - ReceiveVocabTrainingPhaseView

private struct ReceiveVocabTrainingPhaseView: View {

    // MARK: Internal

    @ObservedObject var viewModel: VocabularyTrainingViewModel
    @Binding var textInput: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress
            Text(viewModel.progressText)
                .font(Typography.body)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.VocabTraining.progressText)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.xl) {
                if let feedback = viewModel.lastFeedback {
                    VocabFeedbackView(feedback: feedback)
                } else if viewModel.isWaitingForResponse {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("?")
                            .font(Typography.characterDisplay(size: questionMarkSize))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Type what you heard")
                            .font(Typography.body)
                            .foregroundColor(.secondary)

                        // Show current input
                        if !textInput.isEmpty {
                            Text(textInput.uppercased())
                                .font(Typography.patternDisplay(size: inputSize))
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier(AccessibilityID.VocabTraining.userInputDisplay)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.waitingIndicator)
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Listen...")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.listeningIndicator)
                }

                if viewModel.isWaitingForResponse {
                    TimeoutProgressBar(progress: viewModel.responseProgress)
                        .frame(height: 8)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .frame(height: 250)

            Spacer()

            // Replay button
            Button {
                viewModel.replayWord()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Replay")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.replayButton)

            // Score display
            HStack {
                Text("Correct: \(viewModel.counter.correct)/\(viewModel.counter.attempts)")
                    .accessibilityLabel(
                        "\(viewModel.counter.correct) correct out of \(viewModel.counter.attempts) attempts"
                    )
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.scoreText)
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .accessibilityLabel("\(viewModel.accuracyPercentage) percent accuracy")
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.accuracyText)
            }
            .font(Typography.body)

            // Pause button
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.pauseButton)
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.receivePhaseView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var questionMarkSize: CGFloat = 80
    @ScaledMetric(relativeTo: .title) private var inputSize: CGFloat = 36

}

// MARK: - SendVocabTrainingPhaseView

private struct SendVocabTrainingPhaseView: View {

    // MARK: Internal

    @ObservedObject var viewModel: VocabularyTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress
            Text(viewModel.progressText)
                .font(Typography.body)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.VocabTraining.progressText)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.md) {
                if let feedback = viewModel.lastFeedback {
                    VocabFeedbackView(feedback: feedback)
                } else {
                    // Target word to send
                    Text(viewModel.currentWord)
                        .font(Typography.characterDisplay(size: wordSize))
                        .foregroundColor(Theme.Colors.primary)
                        .accessibilityLabel(spellOutWord(viewModel.currentWord))
                        .accessibilityIdentifier(AccessibilityID.VocabTraining.targetWord)

                    // Current progress through the word
                    HStack(spacing: 4) {
                        Text(viewModel.userInput)
                            .foregroundColor(Theme.Colors.success)
                        Text(viewModel.currentPattern.isEmpty ? "_" : viewModel.currentPattern)
                            .foregroundColor(.secondary)
                    }
                    .font(Typography.patternDisplay(size: patternSize))
                    .frame(height: 32)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.patternProgress)
                }

                // Input timeout progress bar
                if viewModel.inputTimeRemaining > 0 {
                    TimeoutProgressBar(progress: viewModel.inputProgress)
                        .frame(height: 8)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .frame(height: 200)

            Spacer()

            // Keyboard hint
            Text("Keyboard: . or F = dit, - or J = dah, Space = next char")
                .font(Typography.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier(AccessibilityID.VocabTraining.keyboardHint)

            // Paddle area
            HStack(spacing: 2) {
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
                .accessibilityIdentifier(AccessibilityID.VocabTraining.ditButton)

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
                .accessibilityIdentifier(AccessibilityID.VocabTraining.dahButton)
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
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.scoreText)
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .accessibilityLabel("\(viewModel.accuracyPercentage) percent accuracy")
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.accuracyText)
            }
            .font(Typography.body)

            // Pause button
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.pauseButton)
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.sendPhaseView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 48
    @ScaledMetric(relativeTo: .title) private var patternSize: CGFloat = 24

}

// MARK: - VocabPausedView

private struct VocabPausedView: View {
    @ObservedObject var viewModel: VocabularyTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Paused")
                .font(Typography.largeTitle)
                .accessibilityIdentifier(AccessibilityID.VocabTraining.pausedTitle)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Score: \(viewModel.counter.correct)/\(viewModel.counter.attempts)")
                    .font(Typography.headline)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.pausedScore)
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.accuracyText)
            }

            Spacer()

            Button("Resume") {
                viewModel.resume()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.resumeButton)

            Button("End Session") {
                viewModel.endSession()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.endSessionButton)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.pausedView)
    }
}

// MARK: - VocabCompletedView

private struct VocabCompletedView: View {
    @ObservedObject var viewModel: VocabularyTrainingViewModel

    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Session Complete")
                .font(Typography.largeTitle)
                .accessibilityIdentifier(AccessibilityID.VocabTraining.completedTitle)

            Spacer()

            // Stats
            VStack(spacing: Theme.Spacing.sm) {
                Text("\(viewModel.counter.correct)/\(viewModel.counter.attempts) correct")
                    .font(Typography.headline)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.scoreText)

                Text("\(viewModel.accuracyPercentage)% accuracy")
                    .font(Typography.body)
                    .foregroundColor(viewModel.accuracyPercentage >= 80 ? Theme.Colors.success : .secondary)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.accuracyText)

                Text("Set: \(viewModel.vocabularySet.name)")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.setName)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.VocabTraining.completedStats)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(AccessibilityID.VocabTraining.doneButton)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.completedView)
    }
}

// MARK: - VocabFeedbackView

private struct VocabFeedbackView: View {

    // MARK: Internal

    let feedback: VocabularyTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(feedback.expectedWord)
                .font(Typography.characterDisplay(size: wordSize))
                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)
                .accessibilityLabel(spellOutWord(feedback.expectedWord))
                .accessibilityIdentifier(AccessibilityID.VocabTraining.feedbackWord)

            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
                    .accessibilityIdentifier(AccessibilityID.VocabTraining.feedbackResult)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    if feedback.userAnswer != "(timeout)" {
                        Text("You entered: \(feedback.userAnswer)")
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.error)
                            .accessibilityLabel("You entered: \(spellOutWord(feedback.userAnswer))")
                    } else {
                        Text("Too slow!")
                            .font(Typography.headline)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.VocabTraining.feedbackResult)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.VocabTraining.feedbackView)
    }

    // MARK: Private

    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 48

}

#Preview {
    NavigationStack {
        VocabularyTrainingView(
            vocabularySet: VocabularySet.commonWords,
            sessionType: .receiveVocabulary
        )
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore())
    }
}
