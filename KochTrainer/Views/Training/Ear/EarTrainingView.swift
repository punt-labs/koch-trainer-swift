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
            // Hidden text field for keyboard capture (only active during training)
            if case .training = viewModel.phase {
                TextField("", text: $hiddenInput)
                    .focused($isKeyboardFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: hiddenInput) { newValue in
                        if let lastChar = newValue.last {
                            viewModel.handleKeyPress(lastChar)
                        }
                        hiddenInput = ""
                    }
            }

            // Main content based on phase
            switch viewModel.phase {
            case .introduction:
                CharacterIntroductionView(viewModel: viewModel, trainingType: "Ear Training")

            case .training:
                EarTrainingPhaseView(viewModel: viewModel)
                    .onAppear {
                        isKeyboardFocused = true
                    }
                    .onTapGesture {
                        isKeyboardFocused = true
                    }

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
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: scenePhase) { newPhase in
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
    @State private var hiddenInput: String = ""

}

// MARK: - EarTrainingPhaseView

struct EarTrainingPhaseView: View {
    @ObservedObject var viewModel: EarTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Level and progress display
            HStack {
                Text("Level \(viewModel.currentLevel)/\(MorseCode.maxEarTrainingLevel)")
                    .font(Typography.headline)
                Spacer()
                Text(viewModel.proficiencyProgress)
                    .font(Typography.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

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
                Text(viewModel.currentPattern.isEmpty ? "..." : viewModel.currentPattern)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.currentPattern.isEmpty ? .secondary.opacity(0.3) : Theme.Colors.primary)
                    .frame(height: 60)

                // Progress bar (always present, opacity controlled)
                TimeoutProgressBar(progress: viewModel.inputProgress)
                    .frame(height: 8)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .opacity(viewModel.inputTimeRemaining > 0 ? 1 : 0)
            }
            .frame(height: 200)

            Spacer()

            // Keyboard hint
            Text("Keyboard: . or F = dit, - or J = dah")
                .font(Typography.caption)
                .foregroundColor(.secondary)

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
                .disabled(!viewModel.isWaitingForInput)

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
                .disabled(!viewModel.isWaitingForInput)
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

// MARK: - EarFeedbackView

struct EarFeedbackView: View {
    let feedback: EarTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if feedback.wasCorrect {
                Text("\(feedback.expectedPattern) Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Expected: \(feedback.expectedPattern)")
                        .font(Typography.body)
                        .foregroundColor(Theme.Colors.error)
                    Text("You sent: \(feedback.userPattern)")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
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

            VStack(spacing: Theme.Spacing.sm) {
                Text("Level \(viewModel.currentLevel)/\(MorseCode.maxEarTrainingLevel)")
                    .font(Typography.headline)
                Text("Score: \(viewModel.correctCount)/\(viewModel.totalAttempts)")
                    .font(Typography.body)
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
                            }
                        }
                    }
                }
            } else {
                // Session complete without advancement
                Text("Session Complete")
                    .font(Typography.largeTitle)
            }

            Spacer()

            // Stats
            VStack(spacing: Theme.Spacing.sm) {
                Text("\(viewModel.correctCount)/\(viewModel.totalAttempts) correct")
                    .font(Typography.headline)

                Text("\(viewModel.accuracyPercentage)% accuracy")
                    .font(Typography.body)
                    .foregroundColor(viewModel.accuracyPercentage >= 90 ? Theme.Colors.success : .secondary)

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
            } else {
                Button("Try Again") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        EarTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
