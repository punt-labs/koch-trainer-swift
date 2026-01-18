import SwiftUI

struct ReceiveTrainingView: View {
    @StateObject private var viewModel = ReceiveTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    // For keyboard capture during training
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
                        hiddenInput = "" // Clear after processing
                    }
            }

            // Main content based on phase
            switch viewModel.phase {
            case .introduction:
                IntroductionPhaseView(viewModel: viewModel)

            case .training:
                TrainingPhaseView(viewModel: viewModel, dismiss: dismiss)
                    .onAppear {
                        isKeyboardFocused = true
                    }
                    .onTapGesture {
                        isKeyboardFocused = true
                    }

            case .paused:
                PausedView(viewModel: viewModel, dismiss: dismiss)

            case .finished:
                Text("Session Complete")
                    .font(Typography.largeTitle)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    var navigationTitle: String {
        switch viewModel.phase {
        case .introduction:
            return "Learn Characters"
        case .training, .paused:
            return "Receive Training"
        case .finished:
            return "Complete"
        }
    }
}

// MARK: - Introduction Phase View

struct IntroductionPhaseView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Progress indicator
            Text("Character \(viewModel.introProgress)")
                .font(Typography.body)
                .foregroundColor(.secondary)

            Spacer()

            if let char = viewModel.currentIntroCharacter {
                // Character display
                Text(String(char))
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primary)

                // Morse pattern
                Text(MorseCode.pattern(for: char) ?? "")
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                // Play button
                Button(action: {
                    viewModel.playCurrentIntroCharacter()
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Play Sound")
                    }
                    .font(Typography.headline)
                }
                .buttonStyle(PrimaryButtonStyle())

                // Next button
                Button(action: {
                    viewModel.nextIntroCharacter()
                }) {
                    Text(isLastCharacter ? "Start Training" : "Next Character")
                        .font(Typography.headline)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .onAppear {
            // Auto-play when character appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.playCurrentIntroCharacter()
            }
        }
    }

    var isLastCharacter: Bool {
        if case .introduction(let index) = viewModel.phase {
            return index == viewModel.introCharacters.count - 1
        }
        return false
    }
}

// MARK: - Training Phase View

struct TrainingPhaseView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Timer display
            Text(viewModel.formattedTime)
                .font(Typography.largeTitle)
                .monospacedDigit()

            Spacer()

            // Main display area
            VStack(spacing: Theme.Spacing.xl) {
                // Current character or feedback
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

                // Response timeout bar
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
                Text("Correct: \(viewModel.correctCount)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            // Controls
            HStack(spacing: Theme.Spacing.md) {
                Button("Pause") {
                    viewModel.pause()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Stop") {
                    _ = viewModel.endSession()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Paused View

struct PausedView: View {
    @ObservedObject var viewModel: ReceiveTrainingViewModel
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text("Paused")
                .font(Typography.largeTitle)

            Text("\(viewModel.formattedTime) remaining")
                .font(Typography.headline)
                .foregroundColor(.secondary)

            Spacer()

            // Score so far
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
                _ = viewModel.endSession()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())

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
            // Show the correct character
            Text(String(feedback.expectedCharacter))
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(feedback.wasCorrect ? Theme.Colors.success : Theme.Colors.error)

            // Show what user pressed (if anything)
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
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))

                // Progress
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
            return .orange
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
