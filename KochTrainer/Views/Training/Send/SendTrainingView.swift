import SwiftUI

struct SendTrainingView: View {
    @StateObject private var viewModel = SendTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool
    @State private var hiddenInput: String = ""

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
                CharacterIntroductionView(viewModel: viewModel, trainingType: "Training")

            case .training:
                SendTrainingPhaseView(viewModel: viewModel)
                    .onAppear {
                        isKeyboardFocused = true
                    }
                    .onTapGesture {
                        isKeyboardFocused = true
                    }

            case .paused:
                SendPausedView(viewModel: viewModel)

            case .completed(let didAdvance, let newCharacter):
                SendCompletedView(
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
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            viewModel.startSession()
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

    var navigationTitle: String {
        switch viewModel.phase {
        case .introduction:
            return "Learn Characters"
        case .training, .paused:
            return "Send Training"
        case .completed:
            return "Complete!"
        }
    }

    var isTrainingActive: Bool {
        if case .training = viewModel.phase { return true }
        if case .paused = viewModel.phase { return true }
        return false
    }
}

// MARK: - Training Phase View

struct SendTrainingPhaseView: View {
    @ObservedObject var viewModel: SendTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress toward mastery
            Text(viewModel.masteryProgress)
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.md) {
                if let feedback = viewModel.lastFeedback {
                    SendFeedbackView(feedback: feedback)
                } else {
                    // Target character to send
                    Text(String(viewModel.targetCharacter))
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primary)

                    // Current pattern being entered
                    Text(viewModel.currentPattern.isEmpty ? " " : viewModel.currentPattern)
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(height: 44)
                }

                // Input timeout progress bar (only when typing)
                if viewModel.inputTimeRemaining > 0 {
                    TimeoutProgressBar(progress: viewModel.inputProgress)
                        .frame(height: 8)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
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

// MARK: - Paused View

struct SendPausedView: View {
    @ObservedObject var viewModel: SendTrainingViewModel

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

// MARK: - Completed View

struct SendCompletedView: View {
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

                    if let char = newCharacter {
                        Text("New character unlocked:")
                            .font(Typography.body)
                            .foregroundColor(.secondary)

                        Text(String(char))
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.primary)

                        Text(MorseCode.pattern(for: char) ?? "")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
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

                if !didAdvance && viewModel.accuracyPercentage < 90 {
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

// MARK: - Feedback View

struct SendFeedbackView: View {
    let feedback: SendTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(String(feedback.expectedCharacter))
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)

            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("You sent: \(feedback.sentPattern)")
                        .font(Typography.body)
                        .foregroundColor(Theme.Colors.error)

                    if let decoded = feedback.decodedCharacter {
                        Text("(\(String(decoded)))")
                            .font(Typography.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("(invalid pattern)")
                            .font(Typography.body)
                            .foregroundColor(.secondary)
                    }

                    Text("Should be: \(MorseCode.pattern(for: feedback.expectedCharacter) ?? "")")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SendTrainingView()
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
    }
}
