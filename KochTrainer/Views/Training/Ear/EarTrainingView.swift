import SwiftUI

// MARK: - EarTrainingView

struct EarTrainingView: View {

    // MARK: Internal

    var navigationTitle: String {
        switch viewModel.phase {
        case .introduction:
            return "Learn Patterns"
        case .training,
             .paused:
            return "Ear Training"
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
            // Main content based on phase
            switch viewModel.phase {
            case .introduction:
                CharacterIntroductionView(viewModel: viewModel, startButtonKey: "Start Ear Training")

            case .training:
                EarTrainingPhaseView(viewModel: viewModel)

            case .paused:
                EarPausedView(viewModel: viewModel)

            case let .completed(didAdvance, newCharacters):
                EarCompletedView(
                    viewModel: viewModel,
                    didAdvance: didAdvance,
                    newCharacters: newCharacters,
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
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)

            // Check for paused session and restore directly
            if let paused = progressStore.pausedSession(for: .earTraining),
               !paused.isExpired,
               paused.currentLevel == progressStore.progress.earTrainingLevel {
                viewModel.restoreFromPausedSession(paused)

                if case .paused = viewModel.phase {
                    // Restoration succeeded
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

    @StateObject private var viewModel = EarTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool

}

// MARK: - EarTrainingPhaseView

struct EarTrainingPhaseView: View {

    // MARK: Internal

    @ObservedObject var viewModel: EarTrainingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Level and progress display
                HStack {
                    Text("Level \(viewModel.currentLevel)/\(MorseCode.maxEarTrainingLevel)")
                        .font(Typography.headline)
                    Spacer()
                    Text(viewModel.proficiencyProgress)
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Training.proficiencyProgress)
                }

                // Main display area - fixed slots prevent layout shifts
                VStack(spacing: Theme.Spacing.md) {
                    // Instruction or feedback
                    if let feedback = viewModel.lastFeedback {
                        EarFeedbackView(feedback: feedback)
                    } else if viewModel.isWaitingForInput {
                        Text("Reproduce the pattern")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Listen...")
                            .font(Typography.headline)
                            .foregroundColor(.secondary)
                    }

                    // User's current pattern input
                    Text(viewModel.currentPattern.isEmpty ? " " : viewModel.currentPattern)
                        .font(Typography.patternDisplay(size: patternSize))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primary)
                        .frame(height: 60)
                        .accessibilityLabel(
                            viewModel.currentPattern.isEmpty
                                ? ""
                                : AccessibilityAnnouncer.spokenPattern(viewModel.currentPattern)
                        )
                        .accessibilityIdentifier(AccessibilityID.Send.patternDisplay)

                    // Progress bar (always present, opacity controlled)
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

                // Paddle area
                HStack(spacing: 2) {
                    // Dit button
                    Button {
                        viewModel.queueElement(.dit)
                    } label: {
                        Text("dit")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.primary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isWaitingForInput)
                    .accessibilityHint("Short Morse element")
                    .accessibilityIdentifier(AccessibilityID.Send.ditButton)

                    // Dah button
                    Button {
                        viewModel.queueElement(.dah)
                    } label: {
                        Text("dah")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isWaitingForInput)
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

    @ScaledMetric(relativeTo: .title) private var patternSize: CGFloat = 48

}

// MARK: - EarFeedbackView

struct EarFeedbackView: View {
    let feedback: EarTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Expected: \(feedback.expectedPattern)")
                        .font(Typography.body)
                        .foregroundColor(Theme.Colors.error)
                        .accessibilityLabel(
                            "Expected: \(AccessibilityAnnouncer.spokenPattern(feedback.expectedPattern))"
                        )
                    Text("You sent: \(feedback.userPattern)")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(
                            "You sent: \(AccessibilityAnnouncer.spokenPattern(feedback.userPattern))"
                        )
                }
            }
        }
    }
}

// MARK: - EarPausedView

struct EarPausedView: View {
    @ObservedObject var viewModel: EarTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Paused")
                .font(Typography.largeTitle)
                .accessibilityIdentifier(AccessibilityID.Training.pausedTitle)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Level \(viewModel.currentLevel)/\(MorseCode.maxEarTrainingLevel)")
                    .font(Typography.headline)
                Text("Score: \(viewModel.counter.correct)/\(viewModel.counter.attempts)")
                    .font(Typography.body)
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

// MARK: - EarCompletedView

struct EarCompletedView: View {
    @ObservedObject var viewModel: EarTrainingViewModel

    let didAdvance: Bool
    let newCharacters: [Character]?
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

                    if let chars = newCharacters, !chars.isEmpty {
                        Text("New patterns unlocked:")
                            .font(Typography.body)
                            .foregroundColor(.secondary)

                        // Show new characters with their patterns
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(chars, id: \.self) { char in
                                HStack {
                                    Text(String(char))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(Theme.Colors.primary)
                                    Text("=")
                                        .foregroundColor(.secondary)
                                    Text(MorseCode.pattern(for: char) ?? "")
                                        .font(.system(size: 24, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "\(String(char)) equals \(AccessibilityAnnouncer.spokenPattern(MorseCode.pattern(for: char) ?? ""))"
                                )
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.Training.newCharacterDisplay)
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
}

#Preview {
    NavigationStack {
        EarTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
