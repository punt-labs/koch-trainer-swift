import SwiftUI

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
            // Hidden text field for keyboard capture
            if case .training = viewModel.phase {
                if viewModel.isReceiveMode {
                    // Receive mode: auto-submit when input length matches expected word
                    TextField("", text: $textInput)
                        .focused($isKeyboardFocused)
                        .opacity(0)
                        .frame(width: 0, height: 0)
                        .onChange(of: textInput) { newValue in
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
                } else {
                    // Send mode: capture keystrokes for dit/dah
                    TextField("", text: Binding(
                        get: { "" },
                        set: { newValue in
                            if let char = newValue.last {
                                viewModel.handleKeyPress(char)
                            }
                        }
                    ))
                    .focused($isKeyboardFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
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
            isKeyboardFocused = true
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background, case .training = viewModel.phase {
                viewModel.pause()
            }
        }
        .onTapGesture {
            isKeyboardFocused = true
        }
    }

    // MARK: Private

    @StateObject private var viewModel: VocabularyTrainingViewModel
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool
    @State private var textInput: String = ""

}

// MARK: - ReceiveVocabTrainingPhaseView

private struct ReceiveVocabTrainingPhaseView: View {
    @ObservedObject var viewModel: VocabularyTrainingViewModel
    @Binding var textInput: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress
            Text(viewModel.progressText)
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.xl) {
                if let feedback = viewModel.lastFeedback {
                    VocabFeedbackView(feedback: feedback)
                } else if viewModel.isWaitingForResponse {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("?")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Type what you heard")
                            .font(Typography.body)
                            .foregroundColor(.secondary)

                        // Show current input
                        if !textInput.isEmpty {
                            Text(textInput.uppercased())
                                .font(.system(size: 36, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Listen...")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    }
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

            // Score display
            HStack {
                Text("Correct: \(viewModel.correctCount)/\(viewModel.totalAttempts)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            // Pause button
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - SendVocabTrainingPhaseView

private struct SendVocabTrainingPhaseView: View {
    @ObservedObject var viewModel: VocabularyTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress
            Text(viewModel.progressText)
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.md) {
                if let feedback = viewModel.lastFeedback {
                    VocabFeedbackView(feedback: feedback)
                } else {
                    // Target word to send
                    Text(viewModel.currentWord)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primary)

                    // Current progress through the word
                    HStack(spacing: 4) {
                        Text(viewModel.userInput)
                            .foregroundColor(Theme.Colors.success)
                        Text(viewModel.currentPattern.isEmpty ? "_" : viewModel.currentPattern)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .frame(height: 32)
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
            }
            .frame(height: 120)
            .cornerRadius(12)
            .clipped()

            // Score display
            HStack {
                Text("Correct: \(viewModel.correctCount)/\(viewModel.totalAttempts)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            // Pause button
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - VocabPausedView

private struct VocabPausedView: View {
    @ObservedObject var viewModel: VocabularyTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Paused")
                .font(Typography.largeTitle)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Score: \(viewModel.correctCount)/\(viewModel.totalAttempts)")
                    .font(Typography.headline)
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Resume") {
                viewModel.resume()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("End Session") {
                viewModel.endSession()
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()
        }
        .padding(Theme.Spacing.lg)
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

            Spacer()

            // Stats
            VStack(spacing: Theme.Spacing.sm) {
                Text("\(viewModel.correctCount)/\(viewModel.totalAttempts) correct")
                    .font(Typography.headline)

                Text("\(viewModel.accuracyPercentage)% accuracy")
                    .font(Typography.body)
                    .foregroundColor(viewModel.accuracyPercentage >= 80 ? Theme.Colors.success : .secondary)

                Text("Set: \(viewModel.vocabularySet.name)")
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - VocabFeedbackView

private struct VocabFeedbackView: View {
    let feedback: VocabularyTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(feedback.expectedWord)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)

            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    if feedback.userAnswer != "(timeout)" {
                        Text("You entered: \(feedback.userAnswer)")
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.error)
                    } else {
                        Text("Too slow!")
                            .font(Typography.headline)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
            }
        }
    }
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
