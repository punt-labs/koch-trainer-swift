import SwiftUI

struct ReceiveTrainingView: View {
    @StateObject private var viewModel = ReceiveTrainingViewModel()
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Timer display
            Text(viewModel.formattedTime)
                .font(Typography.largeTitle)
                .monospacedDigit()

            Spacer()

            // Current group display
            Text(viewModel.currentGroup)
                .font(Typography.morse)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Colors.background.opacity(0.5))
                .cornerRadius(8)

            // Input field
            TextField("Type what you hear", text: $viewModel.currentInput)
                .textFieldStyle(.roundedBorder)
                .font(Typography.morse)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onSubmit {
                    viewModel.submitInput()
                }

            // Score display
            HStack {
                Text("Correct: \(viewModel.correctCount)")
                Spacer()
                Text("Accuracy: \(viewModel.accuracyPercentage)%")
            }
            .font(Typography.body)

            Spacer()

            // Controls
            HStack(spacing: Theme.Spacing.md) {
                Button(viewModel.isPlaying ? "Pause" : "Resume") {
                    viewModel.togglePlayPause()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Stop") {
                    viewModel.endSession()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.lg)
        .navigationTitle("Receive Training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.cleanup()
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
