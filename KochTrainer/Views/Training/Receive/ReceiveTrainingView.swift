import SwiftUI

struct ReceiveTrainingView: View {
    @StateObject private var viewModel = ReceiveTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    // For keyboard capture
    @FocusState private var isKeyboardFocused: Bool
    @State private var hiddenInput: String = ""

    var body: some View {
        ZStack {
            // Hidden text field for keyboard capture
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
                    Button(viewModel.isPlaying ? "Pause" : "Resume") {
                        if viewModel.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.resume()
                        }
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
        .navigationTitle("Receive Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            viewModel.startSession()
            isKeyboardFocused = true
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onTapGesture {
            // Ensure keyboard stays visible when tapping anywhere
            isKeyboardFocused = true
        }
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
