import SwiftUI

struct ReceiveTrainingView: View {
    @StateObject private var viewModel = ReceiveTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @FocusState private var isKeyboardFocused: Bool
    @State private var hiddenInput: String = ""

    /// Optional custom characters for practice mode
    let customCharacters: [Character]?

    init(customCharacters: [Character]? = nil) {
        self.customCharacters = customCharacters
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
                CharacterIntroductionView(viewModel: viewModel, trainingType: "Training")

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

            case .completed(let didAdvance, let newCharacter):
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
                viewModel.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: custom)
            } else {
                viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            }
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
            return "Receive Training"
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

struct TrainingPhaseView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress toward mastery
            Text(viewModel.masteryProgress)
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.xl) {
                if let feedback = viewModel.lastFeedback {
                    FeedbackView(feedback: feedback)
                } else if viewModel.isWaitingForResponse {
                    WaitingForResponseView()
                } else if viewModel.currentCharacter != nil {
                    PlayingIndicator()
                } else {
                    Text("Starting...")
                        .font(Typography.headline)
                        .foregroundColor(.secondary)
                }

                if viewModel.isWaitingForResponse {
                    TimeoutProgressBar(progress: viewModel.responseProgress)
                        .frame(height: 8)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .frame(height: 200)

            Spacer()

            // Score display
            HStack {
                Text("Correct: \(viewModel.correctCount)/\(viewModel.totalAttempts)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            // Pause button only
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Paused View

struct PausedView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel

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

struct CompletedView: View {
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

// MARK: - Subviews

struct WaitingForResponseView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("?")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primary)

            Text("Type the letter you heard")
                .font(Typography.body)
                .foregroundColor(.secondary)
        }
    }
}

struct PlayingIndicator: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.primary)

            Text("Listen...")
                .font(Typography.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct FeedbackView: View {
    let feedback: ReceiveTrainingViewModel.Feedback

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(String(feedback.expectedCharacter))
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)

            if feedback.wasCorrect {
                Text("Correct!")
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.success)
            } else if let pressed = feedback.userPressed {
                Text("You pressed: \(String(pressed))")
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

struct TimeoutProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)

                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
            }
        }
    }

    var progressColor: Color {
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
